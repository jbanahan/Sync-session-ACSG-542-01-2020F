require 'spec_helper'

describe Api::V1::Admin::EventSubscriptionsController do
  describe :show_by_event_type_object_id_and_subscription_type do
    it "should return subscription users" do
      allow_api_access Factory(:admin_user)
      u = User.new(email:'a@sample.com',first_name:'Joe',last_name:'Smith',id:5)
      sub = EventSubscription.new
      sub.user = u
      EventSubscription.should_receive(:subscriptions_for_event).with('ORDER_COMMENT_CREATE','email','5').and_return [sub]
      get :show_by_event_type_object_id_and_subscription_type, event_type: 'ORDER_COMMENT_CREATE', object_id: 5, subscription_type: 'email'
      expect(response).to be_success
      j = JSON.parse(response.body)
      expected = {'event_subscription_users'=>[{'id'=>u.id,'email'=>u.email,'first_name'=>u.first_name,'last_name'=>u.last_name,'full_name'=>u.full_name}]}
      expect(j).to eq expected
    end
  end
end