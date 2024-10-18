# frozen_string_literal: true

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
        super do |res|
          access_read(res)
          yield(res).tap do
            # In the block case, the response is hijacked _after_ the block is called
            # to allow the block to read the response body if it wants
            hijack_response(res)
          end
        end
      else
        hijack_response(super)
      end
    end

    protected

    # We read the response ourselves; don't need net/http to try to read it again
    def hijack_response(res)
      access_read(res) unless res.respond_to?(:read?)
      res.read = true
      res
    end

    def access_read(res)
      res.singleton_class.class_eval do
        attr_writer :read

        def read?
          @read
        end
      end
    end
  end
end
