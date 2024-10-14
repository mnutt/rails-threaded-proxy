require 'addressable/uri'
require 'net/http'
require_relative 'http'

module ThreadedProxy
  class Client
    DISALLOWED_RESPONSE_HEADERS = %w[keep-alive]

    METHODS = {
      'get' => Net::HTTP::Get,
      'post' => Net::HTTP::Post,
      'put' => Net::HTTP::Put,
      'delete' => Net::HTTP::Delete,
      'head' => Net::HTTP::Head,
      'options' => Net::HTTP::Options,
      'trace' => Net::HTTP::Trace
    }

    DEFAULT_OPTIONS = {
      headers: {},
      debug: false
    }

    def initialize(origin_url, options={})
      @origin_url = Addressable::URI.parse(origin_url)
      @options = DEFAULT_OPTIONS.merge(options)
    end

    def log(message)
      $stderr.puts message if @options[:debug]
    end

    def start(socket)
      request_method = METHODS[(@options[:method] || 'GET').to_s.downcase]
      http_request = request_method.new(@origin_url, @options[:headers].merge('Connection' => 'close'))
      if @options[:body].respond_to?(:read)
        http_request.body_stream = @options[:body]
      elsif String === @options[:body]
        http_request.body = @options[:body]
      end

      http = HTTP.new(@origin_url.host, @origin_url.port || default_port(@origin_url))
      http.use_ssl = (@origin_url.scheme == 'https')
      http.set_debug_output($stderr) if @options[:debug]
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @options[:ignore_ssl_errors]

      http.start do
        http.request(http_request) do |client_response|
          # We don't support reusing connections once we have disconnected them from rack
          client_response['connection'] = 'close'

          yield client_response if block_given?

          # start writing response
          log("Writing response status and headers")
          socket.write "HTTP/1.1 #{client_response.code} #{client_response.message}\r\n"

          client_response.each_header do |key, value|
            socket.write "#{key}: #{value}\r\n" unless DISALLOWED_RESPONSE_HEADERS.include?(key.downcase)
          end

          # Done with headers
          socket.write "\r\n"

          # There may have been some existing data in client_response's read buffer, flush it out
          # before we manually connect the raw sockets
          log("Flushing existing response buffer to client")
          http.flush_existing_buffer_to(socket)

          # Copy the rest of the client response to the socket
          log("Copying response body to client")
          http.copy_to(socket)
        end
      end
    end

    def default_port(uri)
      case uri.scheme
      when 'http'
        80
      when 'https'
        443
      else
        nil
      end
    end
  end
end
