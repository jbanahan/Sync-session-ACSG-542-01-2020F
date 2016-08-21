require 'spec_helper'

describe OpenChain::EventPublisher do
  before :each do
    #spec_helper stubs EventPublisher.publish so events aren't constantly published in other tests.
    #We need to reset it here to allow these tests to call the method
    load 'open_chain/event_publisher.rb'
  end
  describe "publish" do
    it "should send event to SQS" do
      o = Order.new
      o.customer_order_number = 'CORD'
      o.id = 7
      MasterSetup.get.update_attributes(request_host:'abc')
      u = double(:user)
      allow(u).to receive(:api_auth_token).and_return 'def'
      allow(u).to receive(:username).and_return 'abc'
      allow(u).to receive(:full_name).and_return 'Joe'
      allow(o).to receive(:closed_by).and_return u
      o.closed_at = 1.hour.ago
      allow(User).to receive(:api_admin).and_return u
      expect(OpenChain::EventPublisher).to receive(:delay).and_return OpenChain::EventPublisher
      c = double('client')
      s = double('sqs')
      expect(AWS::SQS).to receive(:new).and_return(s)
      expect(s).to receive(:client).and_return(c)
      expect(c).to receive(:send_message) do |h|
        expect(h[:queue_url]).to eq OpenChain::EventPublisher::QUEUES[Rails.env]
        b = JSON.parse h[:message_body]
        expect(b['event_type']).to eq 'ORDER_REOPEN'
        expect(b['klass']).to eq 'Order'
        expect(b['id']).to eq 7
        expect(b['api_token']).to eq 'abc:def'
        expect(b['link']).to eq 'https://abc/orders/7'
        expect(b['short_message']).to match(/CORD/)
        expect(b['long_message']).to match(/CORD/)
        nil
      end
      OpenChain::EventPublisher.publish(:order_reopen,o)
    end
    it "should write descriptive subject for comments" do
      o = Factory(:order,order_number:'1234')
      u = Factory(:user,first_name:'Joe',last_name:'Shmo')
      comment = o.comments.create!(subject:'mysub',body:'mybod',user:u)

      MasterSetup.get.update_attributes(request_host:'abc')
      api = double(:user)
      allow(api).to receive(:api_auth_token).and_return 'def'
      allow(api).to receive(:username).and_return 'abc'
      allow(api).to receive(:full_name).and_return 'Joe'
      allow(User).to receive(:api_admin).and_return api
      expect(OpenChain::EventPublisher).to receive(:delay).and_return OpenChain::EventPublisher
      c = double('client')
      s = double('sqs')
      expect(AWS::SQS).to receive(:new).and_return(s)
      expect(s).to receive(:client).and_return(c)
      expect(c).to receive(:send_message) do |h|
        expect(h[:queue_url]).to eq OpenChain::EventPublisher::QUEUES[Rails.env]
        b = JSON.parse h[:message_body]
        expect(b['event_type']).to eq 'COMMENT_CREATE'
        expect(b['klass']).to eq 'Comment'
        expect(b['id']).to eq comment.id
        expect(b['api_token']).to eq 'abc:def'
        expect(b['link']).to eq "https://abc/comments/#{comment.id}"
        expect(b['short_message']).to match("Comment: Order 1234 from Joe Shmo: mysub")
        expect(b['long_message']).to match("Comment Added\n\nmybod")
        nil
      end

      OpenChain::EventPublisher.publish(:comment_create,comment)
    end
  end
end
