require 'spec_helper'

describe OpenChain::EventPublisher do
  before :each do
    #spec_helper stubs EventPublisher.publish so events aren't constantly published in other tests.  
    #We need to reset it here to allow these tests to call the method
    OpenChain::EventPublisher.rspec_reset
  end
  describe :publish do
    it "should send event to SQS" do
      o = Order.new
      o.customer_order_number = 'CORD'
      o.id = 7
      MasterSetup.get.update_attributes(request_host:'abc')
      u = double(:user)
      u.stub(:api_auth_token).and_return 'def'
      u.stub(:username).and_return 'abc'
      u.stub(:full_name).and_return 'Joe'
      o.stub(:closed_by).and_return u
      o.closed_at = 1.hour.ago
      User.stub(:api_admin).and_return u
      c = double('client')
      s = double('sqs')
      AWS::SQS.should_receive(:new).and_return(s)
      s.should_receive(:client).and_return(c)
      c.should_receive(:send_message).with do |h|
        expect(h[:queue_url]).to eq OpenChain::EventPublisher::QUEUES[Rails.env]
        b = JSON.parse h[:message_body]
        expect(b['event_type']).to eq 'ORDER_REOPEN'
        expect(b['klass']).to eq 'Order'
        expect(b['id']).to eq 7
        expect(b['api_token']).to eq 'abc:def'
        expect(b['link']).to eq 'https://abc/orders/7'
        expect(b['short_message']).to match /CORD/
        expect(b['long_message']).to match /CORD/
      end
      OpenChain::EventPublisher.publish(:order_reopen,o)
    end
  end
end