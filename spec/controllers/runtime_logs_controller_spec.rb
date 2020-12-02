describe RuntimeLogsController do
  let(:user) { create(:admin_user, company: create(:company, master: true)) }
  let(:runtime_log) { create(:runtime_log, runtime_logable_type: "SchedulableJob") }

  before do
    sign_in_as user
  end

  describe "GET 'index'" do
    it "is successful" do
      get :index
      expect(response).to be_success
      expect(assigns(:default_display)).to start_with("By default")
    end

    it "executes a search" do
      get :index, {s1: "Schedul", f1: "runtime_logable_type", c1: "sw"}
      expect(response).to be_success
      expect(assigns(:default_display)).to be_nil
    end

    it "rejects if user isn't admin" do
      user.admin = false
      user.save!

      get :index
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end
end
