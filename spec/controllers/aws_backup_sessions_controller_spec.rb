describe AwsBackupSessionsController do
  let!(:session) { Factory(:aws_backup_session) }
  let!(:u) { Factory(:sys_admin_user) }
  before { sign_in_as u }

  describe "index" do
    it "should be successful" do
      get :index
      expect(response).to be_success
      expect(assigns(:aws_backup_sessions)).to_not be_nil
    end

    it "should reject users who aren't sys-admins" do
      u.sys_admin = false; u.save!
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "show" do
    it "should be successful" do
      get :show, id: session.id
      expect(response).to be_success
      expect(assigns(:aws_backup_session)).to eq session
    end

    it "should reject users who aren't sys-admins" do
      u.sys_admin = false; u.save!
      get :show, id: session.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
  end

end
