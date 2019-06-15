describe UserTemplatesController do
  describe '#index' do
    it "should admin secure" do
      sign_in_as Factory(:user)
      get :index
      expect(response).to be_redirect
      expect(assigns(:user_templates)).to be_nil
    end
    it "should return templates" do
      t = Factory(:user_template)
      sign_in_as Factory(:admin_user)
      get :index
      expect(response).to be_success
      expect(assigns(:user_templates)).to eq [t]
    end
  end
  describe '#create' do
    it "should admin secure" do
      sign_in_as Factory(:user)
      expect{post :create, {user_template:{name:'a',tempalte_json:"{}"}}}.to_not change(UserTemplate,:count)
    end
    it "should create template" do
      sign_in_as Factory(:admin_user)
      expect{post :create, {user_template:{name:'a',tempalte_json:"{}"}}}.to change(UserTemplate,:count).from(0).to(1)
    end
  end
  describe '#update' do
    before :each do
      @t = Factory(:user_template)
    end
    it "should admin secure" do
      name = @t.name
      sign_in_as Factory(:user)
      put :update, id: @t.id, user_template:{name:'updated name'}

      @t.reload
      expect(@t.name).to eq name
    end
    it "should update template" do
      name = @t.name
      sign_in_as Factory(:admin_user)
      put :update, id: @t.id, user_template:{name:'updated name'}

      @t.reload
      expect(@t.name).to eq 'updated name'
    end
  end
  describe '#edit' do
    before :each do
      @t = Factory(:user_template)
    end
    it "should admin secure" do
      sign_in_as Factory(:user)
      get :edit, id: @t.id
      expect(assigns(:user_template)).to be_nil
      expect(response).to be_redirect
    end
    it "should show edit screen" do
      sign_in_as Factory(:admin_user)
      get :edit, id: @t.id
      expect(assigns(:user_template)).to eq @t
      expect(response).to be_success
    end
  end
  describe '#destroy' do
    before :each do
      @t = Factory(:user_template)
    end
    it "should admin secure" do
      sign_in_as Factory(:user)
      expect{delete :destroy, id: @t.id}.to_not change(UserTemplate,:count)
    end
    it "should delete template" do
      sign_in_as Factory(:admin_user)
      expect{delete :destroy, id: @t.id}.to change(UserTemplate,:count).from(1).to(0)
    end
  end

end
