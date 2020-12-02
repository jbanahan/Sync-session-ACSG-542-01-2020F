describe InboundFilesController do

  let(:user) { create(:user) }
  let(:inbound_file) do
    create(:inbound_file, file_name: "f.txt", s3_bucket: "the_bucket", s3_path: "the_path", receipt_location: "the_folder")
  end

  before do
    allow(user).to receive(:sys_admin?).and_return true
    sign_in_as user
  end

  describe "index" do
    it "displays default results" do
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
      get :show, id: inbound_file.id
      expect(response).to be_success
      expect(assigns(:inbound_file)).to eq inbound_file
    end

    # Verifies we're using 'find' rather than 'where' search.
    it "throws RecordNotFound exception if the file can't be found" do
      expect { get :show, id: inbound_file.id + 1 }.to raise_error ActiveRecord::RecordNotFound
    end

    it "rejects if user isn't admin" do
      expect(user).to receive(:sys_admin?).and_return false

      get :show, id: inbound_file.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "download" do
    it "downloads file from S3" do
      expect(OpenChain::S3).to receive(:url_for).and_return(request.referer)
      expect(subject).to receive(:download_s3_object).with("the_bucket",
                                                           "the_path", filename:
                                                           "f.txt", disposition:
                                                           "attachment",
                                                                       content_type: "text/plain").and_call_original
      get :download, id: inbound_file.id
      expect(response).to redirect_to root_path
      expect(flash[:errors]).to be_nil
    end

    # Verifies we're using 'find' rather than 'where' search.
    it "throws RecordNotFound exception if the file can't be found" do
      expect { get :download, id: inbound_file.id + 1 }.to raise_error ActiveRecord::RecordNotFound
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
      s3_file = instance_double(Tempfile)
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

  describe "send_to_test" do
    it "sends file" do
      post :send_to_test, id: inbound_file.id
      expect(flash[:notices]).to eq ["File has been queued to be sent to test."]
      expect(flash[:errors]).to be_nil
      expect(response).to be_redirect
      dj = Delayed::Job.last
      expect(dj.handler).to include "!ruby/module 'OpenChain::SendFileToTest'"
      expect(dj.handler).to include "method_name: :execute"
      expect(dj.handler).to include "the_bucket"
      expect(dj.handler).to include "the_path"
    end

    it "sends multiple files" do
      inbound_file2 = create(:inbound_file, s3_bucket: "the_bucket2", s3_path: "the_path2")
      post :send_to_test, ids: [inbound_file.id, inbound_file2.id]
      expect(flash[:notices]).to eq ["Files have been queued to be sent to test."]
      expect(flash[:errors]).to be_nil
      expect(response).to be_redirect
      expect(Delayed::Job.count).to eq 2

      dj = Delayed::Job.last
      expect(dj.handler).to include "!ruby/module 'OpenChain::SendFileToTest'"
      expect(dj.handler).to include "method_name: :execute"
      expect(dj.handler).to include "the_bucket"
      expect(dj.handler).to include "the_path"

      dj2 = Delayed::Job.first
      expect(dj2.handler).to include "the_bucket2"
      expect(dj2.handler).to include "the_path2"
    end

    it "only allows sys-admins" do
      allow(user).to receive(:sys_admin?).and_return false
      post :send_to_test, id: inbound_file.id
      expect(flash[:notices]).to be_nil
      expect(flash[:errors]).to eq ["You do not have permission to send integration files to test."]
      expect(response).to be_redirect
      expect(Delayed::Job.count).to eq 0
    end

    it "errors if file(s) not found" do
      post :send_to_test, id: -1
      expect(flash[:notices]).to be_nil
      expect(flash[:errors]).to eq ["You do not have permission to send integration files to test."]
      expect(response).to be_redirect
      expect(Delayed::Job.count).to eq 0
    end
  end

end
