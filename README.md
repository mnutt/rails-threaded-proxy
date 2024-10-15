# rails-threaded-proxy

Asynchronous high throughput reverse proxy for rails

*Warning: experimental. Use at your own risk.*

## About

Rails concurrency is often limited to running many processes, which can be memory-intensive. Even for servers that support threads, it can be difficult running dozens or hundreds of threads. But you may have backend services that are slow to respond, and/or return very large responses. It is useful to put these services behind rails for authentication, but slow responses can tie up your rails workers preventing them from serving other clients.

`rails-threaded-proxy` disconnects the proxying from the rack request/response cycle, freeing up workers to serve other clients. It does this by running the origin request in a thread. But running in a thread is not enough: we need to be able to respond to the rails request, but rack owns the socket. So it hijacks the request: rack completes immediately but dissociates from the socket. Then we're free to manage the socket ourselves. Copying between sockets, we can achieve high throughput (100MB/s+) with minimal CPU and memory overhead.

## Usage

```ruby
class MyController
  include ThreadedProxy::Controller

  def my_backend
    proxy_fetch "http://backend.service/path/to/endpoint", method: :post do |config|
      config.on_headers do |client_response|
        # override some response headers coming from the backend
        client_response['content-security-policy'] = "sandbox;"
      end
    end
  end
end
```

## Requirements

Tested with Rails 7, but probably works in Rails 6+. Needs an application server that supports `rack.hijack`. (only tested on [https://puma.io/](Puma) so far)

## Caveats

* There isn't currently a way to limit concurrency. It is possible to run your server out of file descriptors, memory, etc.
* Since the proxying happens in a thread, callbacks are also run inside of the thread. Don't do anything non-threadsafe in callbacks.
* There is currently probably not sufficient error handling for edge cases. This is experimental.

## Attribution

Inspired by [https://github.com/axsuul/rails-reverse-proxy](rails-reverse-proxy), and tries to use similar API structure where possible. If you don't care about the specific benefits of `rails-threaded-proxy`, you should consider using `rails-reverse-proxy` instead.

## License

See LICENSE
