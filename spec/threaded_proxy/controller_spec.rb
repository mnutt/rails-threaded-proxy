# frozen_string_literal: true

require 'rails-threaded-proxy'

class TestController
  include ThreadedProxy::Controller

  attr_accessor :request
end

RSpec.describe ThreadedProxy::Controller do
  let(:request) { double(env: {}) }
  let(:controller) do
    TestController.new.tap do |controller|
      controller.request = request
    end
  end

  describe '#proxy_options_from_request' do
    subject { controller.send(:proxy_options_from_request) }
    let(:body_stream) { StringIO.new('HELLO') }

    describe 'when the request is chunked' do
      let(:request) { double(body_stream:, env: { 'HTTP_TRANSFER_ENCODING' => 'chunked' }) }

      it 'sets the Transfer-Encoding header' do
        expect(subject).to include(headers: { 'Transfer-Encoding' => 'chunked' },
                                   body: body_stream)
      end
    end

    describe 'when the request is not chunked' do
      let(:request) { double(body_stream:, env: { 'CONTENT_LENGTH' => '5', 'CONTENT_TYPE' => 'application/json' }) }

      it 'sets the Content-Length header' do
        expect(subject).to include(headers: { 'content-length' => '5',
                                              'Content-Type' => 'application/json' },
                                   body: body_stream)
      end
    end

    describe 'when the request is not chunked and has no content-length' do
      let(:request) { double(body_stream:, env: {}) }

      it 'raises an error' do
        expect { subject }.to raise_error('Cannot proxy a non-chunked POST request without content-length')
      end
    end
  end
end
