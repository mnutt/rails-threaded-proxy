# frozen_string_literal: true

require 'rails-threaded-proxy'
require 'json'

BACKEND_STUB_PORT = 38_293

def parse_raw_response(raw_response)
  status, rest = raw_response.split("\r\n", 2)
  headers, body = rest.split("\r\n\r\n", 2)

  parsed_headers = headers.split("\r\n").map { |h| h.split(': ', 2) }.to_h

  [status, parsed_headers, body]
end

RSpec.describe ThreadedProxy::Client do
  before(:all) do
    @backend_server = WEBrick::HTTPServer.new(Port: BACKEND_STUB_PORT,
                                              Logger: WEBrick::Log.new('/dev/null'),
                                              AccessLog: [])
    @backend_server.mount_proc '/get' do |req, res|
      raise unless req.request_method == 'GET'

      res.body = "Received request: #{req.path}"
    end

    @backend_server.mount_proc '/post' do |req, res|
      raise unless req.request_method == 'POST'

      res.content_type = 'application/json'
      res.body = JSON.generate(path: req.path,
                               headers: req.header,
                               body: req.body)
    end

    @server_thread = Thread.new { @backend_server.start }
  end

  after(:all) do
    @backend_server.shutdown
    @server_thread.kill
  end

  it 'proxies a GET request' do
    socket = StringIO.new

    client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get")
    client.start(socket)

    expect(socket.string).to include('Received request: /get')
  end

  it 'proxies a POST request with content-length' do
    socket = StringIO.new

    client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/post",
                                       method: 'post',
                                       body: 'hello world')
    client.start(socket)

    status, headers, body = parse_raw_response(socket.string)

    parsed_body = JSON.parse(body)

    expect(status).to eq('HTTP/1.1 200 OK')
    expect(headers['content-type']).to eq('application/json')
    expect(parsed_body['path']).to eq('/post')
    expect(parsed_body['headers']['content-length']).to eq(['11'])
  end

  describe 'callbacks' do
    describe 'on_headers' do
      it 'proxies a request and modifies the response headers' do
        socket = StringIO.new

        client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get") do |config|
          config.on_headers do |response|
            response['X-Test'] = 'test'
          end
        end
        client.start(socket)

        status, headers, body = parse_raw_response(socket.string)

        expect(status).to eq('HTTP/1.1 200 OK')
        expect(headers['x-test']).to eq('test')
        expect(headers['connection']).to eq('close')
        expect(body).to eq('Received request: /get')
      end
    end

    describe 'on_complete' do
      it 'fires when the request is successful' do
        socket = StringIO.new
        received_client_response = nil

        client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get") do |config|
          config.on_complete do |client_response|
            received_client_response = client_response
          end
        end
        client.start(socket)

        expect(received_client_response.code).to eq('200')
      end
    end

    describe 'on_error' do
      it 'fires when the request is unsuccessful' do
        socket = StringIO.new
        received_error = nil

        client = ThreadedProxy::Client.new('http://localhost:9999') do |config|
          config.on_error do |e|
            received_error = e
          end
        end
        client.start(socket)

        expect(received_error).to be_a_kind_of(Errno::ECONNREFUSED)

        status, headers, body = parse_raw_response(socket.string)
        expect(status).to eq('HTTP/1.1 500 Internal Server Error')
        expect(headers['Content-Type']).to eq('text/plain; charset=utf-8')
        expect(body).to eq('Internal Server Error')
      end

      it 'returns custom response on error' do
        socket = StringIO.new
        received_error = nil

        client = ThreadedProxy::Client.new('http://localhost:9999') do |config|
          config.on_error do |e, response|
            response.render status: 404, text: 'Custom error'
            received_error = e
          end
        end
        client.start(socket)

        status, headers, body = parse_raw_response(socket.string)
        expect(status).to eq('HTTP/1.1 404 Not Found')
        expect(headers['Content-Type']).to eq('text/plain; charset=utf-8')
        expect(body).to eq('Custom error')
        expect(received_error).to be_a_kind_of(Errno::ECONNREFUSED)
      end
    end

    describe 'on_response' do
      it 'proxies a request and lets caller send response' do
        socket = StringIO.new

        client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get") do |config|
          config.on_response do |client_response, response|
            response.render status: 200, json: { body: client_response.body }, headers: { 'x-passed': 'yes' }
          end
        end
        client.start(socket)

        status, headers, body = parse_raw_response(socket.string)

        parsed_body = JSON.parse(body)

        expect(status).to eq('HTTP/1.1 200 OK')
        expect(headers['Content-Type']).to eq('application/json; charset=utf-8')
        expect(headers['x-passed']).to eq('yes')
        expect(parsed_body['body']).to eq('Received request: /get')
      end

      it 'accepts IO objects as the body' do
        socket = StringIO.new

        client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get") do |config|
          config.on_response do |_client_response, response|
            response.render status: 200, body: StringIO.new('this is IO')
          end
        end
        client.start(socket)

        status, _headers, body = parse_raw_response(socket.string)
        expect(status).to eq('HTTP/1.1 200 OK')
        expect(body).to eq('this is IO')
      end

      it 'accepts json body' do
        socket = StringIO.new

        client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get") do |config|
          config.on_response do |_client_response, response|
            response.render status: 200, json: { key: 'value' }
          end
        end
        client.start(socket)

        status, headers, body = parse_raw_response(socket.string)

        parsed_body = JSON.parse(body)

        expect(status).to eq('HTTP/1.1 200 OK')
        expect(headers['Content-Type']).to eq('application/json; charset=utf-8')
        expect(parsed_body['key']).to eq('value')
      end

      it 'redirects to a URL' do
        socket = StringIO.new

        client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get") do |config|
          config.on_response do |_client_response, response|
            response.redirect_to('http://example.com')
          end
        end
        client.start(socket)

        status, headers, _body = parse_raw_response(socket.string)

        expect(status).to eq('HTTP/1.1 302 Found')
        expect(headers['Location']).to eq('http://example.com')
      end

      it 'handles errors in on_response' do
        socket = StringIO.new
        received_error = nil

        client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get") do |config|
          config.on_response do |_client_response, _response|
            raise 'error in on_response'
          end

          config.on_error do |e|
            received_error = e
          end
        end

        client.start(socket)

        status, headers, body = parse_raw_response(socket.string)

        expect(status).to eq('HTTP/1.1 500 Internal Server Error')
        expect(headers['Content-Type']).to eq('text/plain; charset=utf-8')
        expect(body).to eq('Internal Server Error')
        expect(received_error.message).to eq('error in on_response')
      end

      it 'errors if on_response reads the body but does not render a response' do
        socket = StringIO.new

        client = ThreadedProxy::Client.new("http://localhost:#{BACKEND_STUB_PORT}/get") do |config|
          config.on_response do |client_response, _response|
            client_response.body
          end
        end

        expect { client.start(socket) }.to raise_error(ThreadedProxy::ResponseBodyAlreadyConsumedError)
      end
    end
  end
end
