describe InboundFilesController do

  let(:user) { Factory(:user) }
  let(:inbound_file) do
    inf = InboundFile.new
    inf.file_name = "f.txt"
    inf.s3_bucket = "the_bucket"
    inf.s3_path = "the_path"
    inf.receipt_location = "the_folder"
    inf.save!
    inf
  end

  before :each do
    allow(user).to receive(:sys_admin?).and_return true
    sign_in_as user
  end

  describe "index" do
    it "should display default results" do
      get :index
      expect(response).to be_success
      expect(assigns(:default_display)).to eq "By default, only files processed today are displayed when no search fields are utilized."
    end

    it "executes a search" do
      get :index, {s1: "f.txt", f1: "d_filename", c1: "sw"}
      expect(response).to be_success
      expect(assigns(:default_display)).to be_nil
    end

    it "rejects if user isn't admin" do
      expect(user).to receive(:sys_admin?).and_return false

      get :index
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "show" do
    it "shows an inbound file" do
      get :show, :id => inbound_file.id
      expect(response).to be_success
      expect(assigns(:inbound_file)).to eq inbound_file
    end

    # Verifies we're using 'find' rather than 'where' search.
    it "throws RecordNotFound exception if the file can't be found" do
      begin
        get :show, id: inbound_file.id + 1
        fail "Should have thrown exception"
      rescue ActiveRecord::RecordNotFound => e
        expect(e.to_s).to eq("Couldn't find InboundFile with id=#{inbound_file.id + 1}")
      end
    end

    it "rejects if user isn't admin" do
      expect(user).to receive(:sys_admin?).and_return false

      get :show, :id=> inbound_file.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "download" do
    it "downloads file from S3" do
      expect(OpenChain::S3).to receive(:url_for).and_return(request.referrer)
      expect(subject).to receive(:download_s3_object).with("the_bucket", "the_path", filename: "f.txt", disposition: "attachment", content_type:"text/plain").and_call_original
      get :download, id: inbound_file.id
      expect(response).to redirect_to root_path
      expect(flash[:errors]).to be_nil
    end

    # Verifies we're using 'find' rather than 'where' search.
    it "throws RecordNotFound exception if the file can't be found" do
      begin
        get :download, id: inbound_file.id + 1
        fail "Should have thrown exception"
      rescue ActiveRecord::RecordNotFound => e
        expect(e.to_s).to eq("Couldn't find InboundFile with id=#{inbound_file.id + 1}")
      end
    end

    it "rejects if user is not an admin" do
      expect(user).to receive(:sys_admin?).and_return false

      get :download, id: inbound_file.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "reprocess" do
    it "reprocesses file from S3" do
      s3_file = double("f")
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("the_bucket", "the_path").and_yield s3_file
      expect(subject).to receive(:ftp_file).with(s3_file, subject.ecs_connect_vfitrack_net("the_folder", "f.txt"))

      get :reprocess, id: inbound_file.id

      expect(response).to redirect_to root_path
      expect(flash[:notices].size).to eq 1
      expect(flash[:notices][0]).to eq "File has been queued for reprocessing."
    end

    it "rejects if user is not an admin" do
      expect(user).to receive(:sys_admin?).and_return false

      get :reprocess, id: inbound_file.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

end