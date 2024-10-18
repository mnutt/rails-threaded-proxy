module ThreadedProxy
  class SocketResponder
    def initialize(socket)
      @socket = socket
    end

    def render(options = {})
      return false if @socket.closed?

      status  = options[:status] || 200
      headers = options[:headers] || {}
      body    = options[:body]
      json    = options[:json]
      text    = options[:text]

      if json
        body = json.to_json
        headers['Content-Type'] ||= 'application/json; charset=utf-8'
      elsif text
        body = text
        headers['Content-Type'] ||= 'text/plain; charset=utf-8'
      else
        body ||= ''
      end

      response = ActionDispatch::Response.new(status, headers, [])
      response.prepare!

      # Build the HTTP response
      response_str = "HTTP/1.1 #{response.status} #{response.message}\r\n"
      response.headers.each do |key, value|
        Array(value).each do |v|
          response_str += "#{key}: #{v}\r\n"
        end
      end
      response_str += "\r\n"

      write(response_str)

      if body.respond_to?(:read)
        IO.copy_stream(body, @socket)
      else
        write(body)
      end

      close
    end

    def redirect_to(url)
      render(status: 302, headers: { 'Location' => url })
    end

    def write(data)
      @socket.write(data) unless @socket.closed?
    end

    def close
      @socket.close unless @socket.closed?
    end

    def closed?
      @socket.closed?
    end
  end
end
