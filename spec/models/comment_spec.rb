require 'spec_helper'

describe Comment do
  describe :publish_event do
    it "should publish event on create" do
      o = Factory(:order)
      u = Factory(:user)
      t = Time.now
      Time.stub(:now).and_return t
      OpenChain::EventPublisher.should_receive(:publish).with {|type,obj|
        expect(type).to eq :comment_create
        expect(obj).to be_instance_of Comment
      }
      o.comments.create!(user_id:u.id,body:'abc',subject:'def')
    end
  end
end