describe Api::V1::EventSubscriptionsController do
  describe "index" do
    before :each do
      @u = Factory(:user)
      @es1 = Factory(:event_subscription,user:@u,event_type:'1')
    end
    it "should return subscriptions for user if current_user can_view user" do
      es2 = Factory(:event_subscription,user:@u,event_type:'2',email:true)
      es_bad = Factory(:event_subscription) #don't find me because I'm for a different user

      allow_api_access @u

      get :index, user_id: @u.id
      expect(response).to be_success
      j = JSON.parse(response.body)['event_subscriptions']
      expect(j).to eq [{'event_type'=>'1','user_id'=>@u.id,'email'=>false},
        {'event_type'=>'2','user_id'=>@u.id,'email'=>true}
      ]
    end
    it "should 404 if current_user cannot view user" do
      allow_api_access Factory(:user)
      get :index, user_id: @u.id
      expect(response.status).to eq 404
    end
  end

  describe "create" do
    before :each do
      @u = Factory(:user)
      #bad user ids should be ignored
      @payload = [{'event_type'=>'CREATE_ORDER','user_id'=>99,'email'=>true, 'system_message'=>true},{'event_type'=>'CREATE_COMMENT','user_id'=>22,'email'=>false}]

    end
    it "should handle create with no subscriptions" do
      allow_api_access @u
      post :create, user_id: @u.id
      expect(response).to be_success
    end
    it "should snapshot the user" do
      expect_any_instance_of(User).to receive(:create_snapshot)
      allow_api_access @u
      post :create, user_id: @u.id, event_subscriptions: @payload
      expect(response).to be_success
    end

    it "should allow create if user can_edit? user" do
      allow_api_access @u
      post :create, user_id: @u.id, event_subscriptions: @payload
      expect(response).to be_success
      expect(@u.event_subscriptions.count).to eq 2
      es1 = @u.event_subscriptions.first
      expect(es1.event_type).to eq 'CREATE_ORDER'
      expect(es1).to be_email
      expect(es1).to be_system_message
      es2 = @u.event_subscriptions.last
      expect(es2.event_type).to eq 'CREATE_COMMENT'
      expect(es2).to_not be_email
      expect(es2).to_not be_system_message
    end
    it "should 404 if current_user cannot view user" do
      allow_api_access Factory(:user)
      post :create, user_id: @u.id, event_subscriptions: @payload
      expect(response.status).to eq 404
    end
    it "should 401 if current_user cannot edit user" do
      allow_any_instance_of(User).to receive(:can_edit?).and_return false
      allow_any_instance_of(User).to receive(:can_view?).and_return true
      allow_api_access Factory(:user)
      post :create, user_id: @u.id, event_subscriptions: @payload
      expect(response.status).to eq 401
      
    end
    it "should do full replace" do
      allow_api_access @u
      es_erase = Factory(:event_subscription,user:@u)
      post :create, user_id: @u.id, event_subscriptions: @payload
      expect(response).to be_success
      @u.reload
      expect(@u.event_subscriptions.find {|es| es.id == es_erase.id}).to be_nil
    end
  end
end