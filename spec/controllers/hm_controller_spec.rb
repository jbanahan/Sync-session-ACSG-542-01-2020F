describe HmController do
  let! (:master_setup) do
    ms = stub_master_setup
    allow(ms).to receive(:custom_feature?).with('H&M').and_return true
    ms
  end

  describe "index" do
    it "should not allow view unless master user" do
      u = create(:user)
      sign_in_as u
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
    it "should not allow view unless H&M custom feature enabled" do
      expect(master_setup).to receive(:custom_feature?).with('H&M').and_return false
      u = create(:master_user)
      sign_in_as u
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
    it "should allow for master user with custom feature enabled" do
      u = create(:master_user)
      sign_in_as u
      get :index
      expect(response).to be_success
    end
  end

  describe "show_po_lines" do
    before :each do
      u = create(:master_user)
      sign_in_as u
    end
    it "should render page" do
      get :show_po_lines
      expect(response).to be_success
    end
  end
end
