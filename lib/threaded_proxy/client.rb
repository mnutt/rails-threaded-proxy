# frozen_string_literal: true

require 'addressable/uri'
require 'active_support/notifications'
require 'action_dispatch'
require 'net/http'

require_relative 'http'
require_relative 'socket_responder'

module ThreadedProxy
  class ResponseBodyAlreadyConsumedError < StandardError; end

  class Client
    DISALLOWED_RESPONSE_HEADERS = %w[keep-alive].freeze

    HTTP_METHODS = {
      'get' => Net::HTTP::Get,
      'post' => Net::HTTP::Post,
      'put' => Net::HTTP::Put,
      'delete' => Net::HTTP::Delete,
      'head' => Net::HTTP::Head,
      'options' => Net::HTTP::Options,
      'trace' => Net::HTTP::Trace
    }.freeze

    CALLBACK_METHODS = %i[
      on_response
      on_headers
      on_complete
      on_error
    ].freeze

    CALLBACK_METHODS.each do |method_name|
      define_method(method_name) do |&block|
        @callbacks[method_name] = block
      end
    end

    DEFAULT_OPTIONS = {
      headers: {},
      debug: false,
      method: :get
    }.freeze

    def initialize(origin_url, options = {})
      @origin_url = Addressable::URI.parse(origin_url)
      @options = DEFAULT_OPTIONS.merge(options)
      @wrote_headers = false

      @callbacks = {}
      (CALLBACK_METHODS - [:on_error]).each do |method_name|
        @callbacks[method_name] = proc {}
      end
      @callbacks[:on_error] = proc { |e| raise e }

      yield(self) if block_given?
    end

    def log(message)
      warn message if @options[:debug]
    end

    def start(socket)
      request_method = @options[:method].to_s.downcase
      request_headers = @options[:headers].merge('Connection' => 'close')

      request_class = HTTP_METHODS[request_method]
      http_request = request_class.new(@origin_url, request_headers)
      if @options[:body].respond_to?(:read)
        http_request.body_stream = @options[:body]
      elsif @options[:body].is_a?(String)
        http_request.body = @options[:body]
      end

      socket_responder = SocketResponder.new(socket)

      ActiveSupport::Notifications.instrument('threaded_proxy.fetch', method: request_method, url: @origin_url.to_s,
                                                                      headers: request_headers) do
        http = HTTP.new(@origin_url.host, @origin_url.port || default_port(@origin_url))
        http.use_ssl = (@origin_url.scheme == 'https')
        http.set_debug_output($stderr) if @options[:debug]
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @options[:ignore_ssl_errors]

        http.start do
          http.request(http_request) do |client_response|
            @callbacks[:on_response].call(client_response, socket_responder)
            break if socket.closed?

            log('Writing response status and headers')
            write_headers(client_response, socket)
            break if socket.closed?

            raise ResponseBodyAlreadyConsumedError if client_response.read?

            # There may have been some existing data in client_response's read buffer, flush it out
            # before we manually connect the raw sockets
            log('Flushing existing response buffer to client')
            http.flush_existing_buffer_to(socket)

            # Copy the rest of the client response to the socket
            log('Copying response body to client')
            http.copy_to(socket)

            @callbacks[:on_complete].call(client_response)
          end
        end
      rescue StandardError => e
        @callbacks[:on_error].call(e, socket_responder)
        # Default to 500 if the error callback didn't write a response
        socket_responder.render(status: 500, text: 'Internal Server Error') unless socket.closed? || @wrote_headers

        socket.close unless socket.closed?
      end
    end

    def write_headers(client_response, socket)
      socket.write "HTTP/1.1 #{client_response.code} #{client_response.message}\r\n"

      # We don't support reusing connections once we have disconnected them from rack
      client_response['connection'] = 'close'

      @callbacks[:on_headers].call(client_response, socket)
      return if socket.closed?

      client_response.each_header do |key, value|
        socket.write "#{key}: #{value}\r\n" unless DISALLOWED_RESPONSE_HEADERS.include?(key.downcase)
      end

      # Done with headers
      socket.write "\r\n"
      @wrote_headers = true
    end

    def default_port(uri)
      case uri.scheme
      when 'http'
        80
      when 'https'
        443
      end
    end
  end
end
