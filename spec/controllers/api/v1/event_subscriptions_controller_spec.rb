describe Api::V1::EventSubscriptionsController do

  let (:user) { FactoryBot(:user) }

  describe "index" do
    let! (:es1) { FactoryBot(:event_subscription, user: user, event_type: '1') }

    it "returns subscriptions for user if current_user can_view user" do
      FactoryBot(:event_subscription, user: user, event_type: '2', email: true)
      FactoryBot(:event_subscription) # don't find me because I'm for a different user

      allow_api_access user

      get :index, user_id: user.id
      expect(response).to be_success
      j = JSON.parse(response.body)['event_subscriptions']
      expect(j).to eq [
        {'event_type' => '1', 'user_id' => user.id, 'email' => false},
        {'event_type' => '2', 'user_id' => user.id, 'email' => true}
      ]
    end

    it "returns 404 if current_user cannot view user" do
      allow_api_access FactoryBot(:user)
      get :index, user_id: user.id
      expect(response.status).to eq 404
    end
  end

  describe "create" do
    let (:payload) do
      # bad user ids should be ignored
      [
        {'event_type' => 'CREATE_ORDER', 'user_id' => 99, 'email' => true, 'system_message' => true},
        {'event_type' => 'CREATE_COMMENT', 'user_id' => 22, 'email' => false}
      ]
    end

    it "handles create with no subscriptions" do
      allow_api_access user
      post :create, user_id: user.id
      expect(response).to be_success
    end

    it "snapshots the user" do
      expect_any_instance_of(User).to receive(:create_snapshot)
      allow_api_access user
      post :create, user_id: user.id, event_subscriptions: payload
      expect(response).to be_success
    end

    it "allows create if user can_edit? user" do
      allow_api_access user
      post :create, user_id: user.id, event_subscriptions: payload
      expect(response).to be_success
      expect(user.event_subscriptions.count).to eq 2
      es1 = user.event_subscriptions.first
      expect(es1.event_type).to eq 'CREATE_ORDER'
      expect(es1).to be_email
      expect(es1).to be_system_message
      es2 = user.event_subscriptions.last
      expect(es2.event_type).to eq 'CREATE_COMMENT'
      expect(es2).not_to be_email
      expect(es2).not_to be_system_message
    end

    it "returns 404 if current_user cannot view user" do
      allow_api_access FactoryBot(:user)
      post :create, user_id: user.id, event_subscriptions: payload
      expect(response.status).to eq 404
    end

    it "returns 401 if current_user cannot edit user" do
      allow_any_instance_of(User).to receive(:can_edit?).and_return false
      allow_any_instance_of(User).to receive(:can_view?).and_return true
      allow_api_access FactoryBot(:user)
      post :create, user_id: user.id, event_subscriptions: payload
      expect(response.status).to eq 401
    end

    it "does a full replace" do
      allow_api_access user
      es_erase = FactoryBot(:event_subscription, user: user)
      post :create, user_id: user.id, event_subscriptions: payload
      expect(response).to be_success
      user.reload
      expect(user.event_subscriptions.find {|es| es.id == es_erase.id}).to be_nil
    end
  end
end