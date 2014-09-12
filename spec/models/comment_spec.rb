require 'spec_helper'

describe Comment do
  describe :publish_event do
    it "should publish event on create" do
      o = Factory(:order)
      u = Factory(:user)
      t = Time.now
      Time.stub(:now).and_return t
      OpenChain::EventPublisher.should_receive(:publish) {|type,hash|
        expect(type).to eq 'ORDER_COMMENT_CREATE'
        expect(hash[:comment_id]).to be_a Numeric
        hash.delete :comment_id
        expected_hash = {commentable_type:'Order',commentable_id:o.id,user_id:u.id,created_at:t,body:'abc',subject:'def'}
        expect(hash).to eq expected_hash
      }
      o.comments.create!(user_id:u.id,body:'abc',subject:'def')
    end
  end
end