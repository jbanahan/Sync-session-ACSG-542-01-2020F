describe DrawbackUploadFilesController do
  let(:user) { FactoryBot(:user) }

  before do
    sign_in_as user
    allow_any_instance_of(DrawbackUploadFile).to receive(:validate_layout).and_return([])
  end

  describe "index" do
    it "redirects if user cannot view drawback" do
      allow_any_instance_of(User).to receive(:view_drawback?).and_return(false)
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("You cannot view this page because you do not have permission to view Drawback.")
    end

    it "is good if permissions ok" do
      allow_any_instance_of(User).to receive(:view_drawback?).and_return(true)
      get :index
      expect(response).to be_success
    end
  end

  describe "create", :disable_delayed_jobs do
    let(:file) { fixture_file_upload('/files/test.txt', 'text/plain') }

    context "don't process" do
      before do
        allow_any_instance_of(DrawbackUploadFile).to receive(:process).and_return(nil)
      end

      it "fails if user cannot edit drawback" do
        allow_any_instance_of(User).to receive(:edit_drawback?).and_return(false)
        post :create, 'drawback_upload_file' => {'processor' => DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS, 'attachment_attributes' => {'attached' => file}}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("You cannot upload files because you do not have permission to edit Drawback.")
      end

      it "fails if processor is not set" do
        allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
        post :create, 'drawback_upload_file' => {'processor' => '', 'attachment_attributes' => {'attached' => file}}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("You cannot upload this file because the processor is not set.  Please contact support.")
      end

      it "fails if attachment is not sent" do
        allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
        post :create, 'drawback_upload_file' => {'processor' => DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("You must select a file before uploading.")
      end

      it "sets start_at" do
        allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
        post :create, 'drawback_upload_file' => {'processor' => DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS, 'attachment_attributes' => {'attached' => file}}
        expect(response).to be_redirect
        expect(flash[:errors]).to be_nil
        expect(flash[:notices].size).to eq(1)
        expect(DrawbackUploadFile.first.start_at).not_to be_nil
      end
    end

    it "delays process job" do
      expect_any_instance_of(DrawbackUploadFile).to receive(:process).with(user)
      expect_any_instance_of(DrawbackUploadFile).to receive(:delay).and_return(DrawbackUploadFile.new)
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
      post :create, 'drawback_upload_file' => {'processor' => DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS, 'attachment_attributes' => {'attached' => file}}
      expect(response).to be_redirect
      expect(flash[:errors]).to be_nil
      expect(flash[:notices].size).to eq(1)
    end

    it "calls process job" do
      expect_any_instance_of(DrawbackUploadFile).to receive(:process)
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
      post :create, 'drawback_upload_file' => {'processor' => DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS, 'attachment_attributes' => {'attached' => file}}
      expect(response).to be_redirect
      expect(flash[:errors]).to be_nil
      expect(flash[:notices].size).to eq(1)
      expect(DrawbackUploadFile.first.processor).to eq(DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS)
    end
  end
end
