require 'spec_helper'

describe OpenChain::EventPublisher do
  describe :publish do
    it "should send event to SQS" do
      o = Factory(:order)
      MasterSetup.get.update_attributes(request_host:'abc')
      msg_hash = {abc:'def'}
      expected_message = {queue_url:described_class::QUEUES['test'],message_body:{
          metadata:{event_type:'CREATE_ORDER',host:'abc',klass:'Order',id:o.id},
          content:{abc:'def'}
        }.to_json}

      c = double('client')
      s = double('sqs')
      AWS::SQS.should_receive(:new).and_return(s)
      s.should_receive(:client).and_return(c)
      c.should_receive(:send_message).with(expected_message)

      described_class.publish('CREATE_ORDER',o,msg_hash)
    end
  end
end