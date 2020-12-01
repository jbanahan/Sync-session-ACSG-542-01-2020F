describe FtpSessionsController do
  before :each do

    @u = FactoryBot(:user, :admin => true, :sys_admin => true, :company => FactoryBot(:company, :master=>true))
    sign_in_as @u
    @ftp = FactoryBot(:ftp_session)
  end

  describe "GET 'index'" do
    it "should be successful" do
      get :index
      expect(response).to be_success
      expect(assigns(:default_display)).to start_with("By default")
    end

    it "executes a search" do
      get :index, {s1: "2017-01-01", f1: "created_at", c1: "sw"}
      expect(response).to be_success
      expect(assigns(:default_display)).to be_nil
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      get :index
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "GET 'show'" do
    it "should be successful" do
      get :show, :id => @ftp.id
      expect(response).to be_success
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      get :show, :id=> @ftp.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "GET 'download'" do
    it "should be successful" do
      get :download, :id => @ftp.id
      expect(response).to be_success
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      get :download, :id=> @ftp.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
  end
end
