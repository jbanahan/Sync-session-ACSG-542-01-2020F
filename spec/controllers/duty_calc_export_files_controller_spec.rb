describe DutyCalcExportFilesController do
  before :each do
    @user = Factory(:user)

    sign_in_as @user
  end
  describe "create" do
    before :each do
      @c = Factory(:company)
    end
    it "should fail if user cannot edit drawback" do
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(false)
      post :create, importer_id: @c.id.to_s
      expect(response.response_code).to eq(403)
    end
    it "should delay creation" do
      f = double('expfileclass')
      expect(f).to receive(:generate_for_importer).with(@c.id.to_s, @user)
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
      expect(DutyCalcExportFile).to receive(:delay).and_return f
      post :create, importer_id: @c.id.to_s
      expect(response).to redirect_to drawback_upload_files_path
    end
  end
  describe "download" do
    before :each do
      @d = Factory(:duty_calc_export_file)
    end
    it "should get attachment" do
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
      @d.create_attachment!
      get :download, id: @d.id
      expect(response).to redirect_to download_attachment_path(@d.attachment)
    end
    it "should render failure if no attachment" do
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
      get :download, id: @d.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq('Export file does not have an attachment.')
    end
    it "should not allow users who cannot edit drawback" do
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(false)
      get :download, id: @d.id
      expect(response.response_code).to eq(403)
    end
  end
end
