require 'spec_helper'
require 'open_chain/integration_client'

describe OpenChain::IntegrationClient do

  context 'zeromq' do
    it 'should build socket properly' do
      ic = OpenChain::IntegrationClient.new
      ic.should_receive :go_with_socket
      Socket.any_instance.should_receive(:connect).with("tcp://fakeserver.test:9999")
      ic.go "tcp://fakeserver.test:9999"
    end
    it 'should make registration call' do
      
    end
    it 'should initiate responder'
    it 'should send response'
  end

  context 'request type: remote_file' do
    it 'should create linkable attachment if linkable attachment rule match'
    it 'should create imported_file if no linked rule'
  end

  it 'should return error if bad request type'

end
