require_relative 'client'

module ThreadedProxy
  module Controller
    def proxy_fetch(origin_url, options={})
      # hijack the response so we can take it outside of the rack request/response cycle
      request.env['rack.hijack'].call
      socket = request.env['rack.hijack_io']

      Thread.new do
        if options[:body] == :rack
          options[:headers] ||= {}
          options[:body] = request.body_stream

          if request.env['HTTP_TRANSFER_ENCODING'] == 'chunked'
            options[:headers]['Transfer-Encoding'] = 'chunked'
          elsif request.env['CONTENT_LENGTH']
            options[:headers]['content-length'] = request.env['CONTENT_LENGTH'].to_s
          else
            raise "Cannot proxy a non-chunked POST request without content-length"
          end

          if request.env['CONTENT_TYPE']
            options[:headers]['Content-Type'] = request.env['CONTENT_TYPE']
          end
        end

        client = Client.new(origin_url, options)
        client.start(socket)
      rescue Errno::EPIPE
        # client disconnected before request finished; not an error
      ensure
        socket.close unless socket.closed?
      end

      head :ok
    end
  end
end
