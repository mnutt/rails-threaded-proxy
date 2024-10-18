# frozen_string_literal: true

require_relative 'client'

module ThreadedProxy
  module Controller
    # Proxies a fetch request to the specified origin URL, allowing for hijacking
    # the controller response outside of the Rack request/response cycle.
    #
    # @param origin_url [String] The URL to which the request will be proxied.
    # @param options [Hash] Optional parameters for the request.
    # @option options [Symbol] :body The body of the request. If set to :rack, the request body stream will be used.
    # @option options [Hash] :headers Additional headers to include in the request.
    # @yield [Client] Optional block to configure the client.
    #
    # @raise [RuntimeError] If a non-chunked POST request is made without a content-length header.
    #
    # @return [void]
    #
    # @example
    #   proxy_fetch('http://example.com', body: :rack, headers: { 'Custom-Header' => 'value' }) do |client|
    #     client.on_headers { |client_response| client_response['x-foo'] = 'bar' }
    #     client.on_error { |e| Rails.logger.error(e) }
    #   end
    def proxy_fetch(origin_url, options = {}, &block)
      # hijack the response so we can take it outside of the rack request/response cycle
      request.env['rack.hijack'].call
      socket = request.env['rack.hijack_io']

      options.deep_merge!(proxy_options_from_request) if options[:body] == :rack

      Thread.new do
        client = Client.new(origin_url, options, &block)
        client.start(socket)
      ensure
        socket.close unless socket.closed?
      end

      head :ok
    end

    protected

    def proxy_options_from_request
      options = {}
      options[:headers] ||= {}
      options[:body] = request.body_stream

      if request.env['HTTP_TRANSFER_ENCODING'] == 'chunked'
        options[:headers]['Transfer-Encoding'] = 'chunked'
      elsif request.env['CONTENT_LENGTH']
        options[:headers]['content-length'] = request.env['CONTENT_LENGTH'].to_s
      else
        raise 'Cannot proxy a non-chunked POST request without content-length'
      end

      options[:headers]['Content-Type'] = request.env['CONTENT_TYPE'] if request.env['CONTENT_TYPE']
      options
    end
  end
end
