require 'spec_helper'

describe Comment do
  describe "publish_event" do
    it "should publish event on create" do
      o = Factory(:order)
      u = Factory(:user)
      t = Time.now
      allow(Time).to receive(:now).and_return t
      expect(OpenChain::EventPublisher).to receive(:publish) do |type,obj|
        expect(type).to eq :comment_create
        expect(obj).to be_instance_of Comment
        nil
      end
      o.comments.create!(user_id:u.id,body:'abc',subject:'def')
    end
  end
end
