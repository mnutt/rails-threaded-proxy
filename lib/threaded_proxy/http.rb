require 'net/http'

module ThreadedProxy
  class HTTP < Net::HTTP
    def flush_existing_buffer_to(dest_socket)
      while (data = @socket.send(:rbuf_consume))
        break if data.empty?
        dest_socket.write data
      end

      dest_socket.flush
    end

    def copy_to(dest_socket)
      IO.copy_stream(@socket.io, dest_socket)
    end

    def request(*args)
      if block_given?
        super { |res| yield hijack_response(res) }
      else
        hijack_response(super)
      end
    end

    protected

    # We read the response ourselves; don't need net/http to try to read it again
    def hijack_response(res)
      res.instance_variable_set("@read", true)
      res
    end
  end
end
