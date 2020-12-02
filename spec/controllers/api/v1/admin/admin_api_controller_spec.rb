describe Api::V1::Admin::AdminApiController do
  controller do
    def index
      render text: 'hello world'
    end
  end
  context "admin_only" do
    it "should yield for admins" do
      u = create(:admin_user)
      allow_api_access u
      get :index
      expect(response).to be_success
      expect(response.body).to eq 'hello world'
    end
    it "should 401 for non-admins" do
      u = create(:master_user)
      allow_api_access u
      get :index
      expect(response.status).to eq 403
    end
  end
end