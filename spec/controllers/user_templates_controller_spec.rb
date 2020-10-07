describe UserTemplatesController do

  describe '#index' do
    let(:ut) {Factory(:user_template)}

    it "admins secure" do
      sign_in_as Factory(:user)
      get :index
      expect(response).to be_redirect
      expect(assigns(:user_templates)).to be_nil
    end

    it "returns templates" do
      t = Factory(:user_template)
      sign_in_as Factory(:admin_user)
      get :index
      expect(response).to be_success
      expect(assigns(:user_templates)).to eq [t]
    end
  end

  describe '#create' do
    let(:ut) {Factory(:user_template)}

    it "admins secure" do
      sign_in_as Factory(:user)
      expect {post :create, {user_template: {name: 'a', tempalte_json: "{}"}}}.not_to change(UserTemplate, :count)
    end

    it "creates template" do
      sign_in_as Factory(:admin_user)
      expect {post :create, {user_template: {name: 'a', tempalte_json: "{}"}}}.to change(UserTemplate, :count).from(0).to(1)
    end
  end

  describe '#update' do
    let(:ut) {Factory(:user_template)}

    it "admins secure" do
      name = ut.name
      sign_in_as Factory(:user)
      put :update, id: ut.id, user_template: {name: 'updated name'}

      ut.reload
      expect(ut.name).to eq name
    end

    it "updates template" do
      ut.name
      sign_in_as Factory(:admin_user)
      put :update, id: ut.id, user_template: {name: 'updated name'}

      ut.reload
      expect(ut.name).to eq 'updated name'
    end
  end

  describe '#edit' do
    let(:ut) {Factory(:user_template)}

    it "admins secure" do
      sign_in_as Factory(:user)
      get :edit, id: ut.id
      expect(assigns(:user_template)).to be_nil
      expect(response).to be_redirect
    end

    it "shows edit screen" do
      sign_in_as Factory(:admin_user)
      get :edit, id: ut.id
      expect(assigns(:user_template)).to eq ut
      expect(response).to be_success
    end
  end

  describe '#destroy' do
    it "admins secure" do
      new_ut = Factory(:user_template)

      sign_in_as Factory(:user)
      expect {delete :destroy, id: new_ut.id}.not_to change(UserTemplate, :count)
    end

    it "deletes template" do
      new_ut = Factory(:user_template)

      sign_in_as Factory(:admin_user)
      expect {delete :destroy, id: new_ut.id}.to change(UserTemplate, :count).from(1).to(0)
    end
  end

end
