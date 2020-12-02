describe ApiSessionsController do
  let(:user) { create(:user, admin: true, sys_admin: true, company: create(:company, master: true)) }
  let(:api) { create(:api_session) }

  before { sign_in_as user }

  describe "GET 'index'" do
    it "is successful" do
      get :index
      expect(response).to be_success
      expect(assigns(:default_display)).to start_with("By default")
    end

    it "executes a search" do
      get :index, {s1: "2017-01-01", f1: "created_at", c1: "sw"}
      expect(response).to be_success
      expect(assigns(:default_display)).to be_nil
    end

    it "rejects if user isn't sys admin" do
      user.sys_admin = false
      user.save!
      get :index
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "GET 'show'" do
    it "is successful" do
      get :show, id: api.id
      expect(response).to be_success
    end

    it "rejects if user isn't sys admin" do
      user.sys_admin = false
      user.save!
      get :show, id: api.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
  end

end
