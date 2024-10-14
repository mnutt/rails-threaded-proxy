# frozen_string_literal: true

require 'rails-threaded-proxy'
require 'json'

BACKEND_STUB_PORT = 38_293

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

    status, rest = socket.string.split("\r\n", 2)
    headers, body = rest.split("\r\n\r\n", 2)

    parsed_body = JSON.parse(body)
    parsed_headers = headers.split("\r\n").map { |h| h.split(': ', 2) }.to_h

    expect(status).to eq('HTTP/1.1 200 OK')
    expect(parsed_headers['content-type']).to eq('application/json')
    expect(parsed_body['path']).to eq('/post')
    expect(parsed_body['headers']['content-length']).to eq(['11'])
  end
end
