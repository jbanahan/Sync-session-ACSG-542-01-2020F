describe FileImportResultsController do
  before :each do
    @u = Factory(:admin_user)
    sign_in_as @u
  end

  describe "download_all" do
    before :each do
      @fir = Factory(:file_import_result)
      @a = Factory(:attachment)
    end

    it "should delay if there are more than 200 records" do
      allow(FileImportResult).to receive(:delay).and_return(FileImportResult)
      expect(FileImportResult).to receive(:delay)
      allow_any_instance_of(FileImportResult).to receive(:change_records).and_return(["change_record"]*201)
      expect(FileImportResult).to receive(:download_results).with(true, @u.id, @fir.id, true)
      get :download_all, id: @fir.id

      expect(flash[:notices].first).to eq("You will receive a system message when your file is finished processing.")
      expect(response).to be_redirect
    end

    it "should send the file immediately for less than 200 records" do
      allow_any_instance_of(FileImportResult).to receive(:change_records).and_return(["change_record"]*10)
      expect(FileImportResult).to receive(:download_results).with(true, @u.id, @fir).and_yield(Tempfile.new("file name"))
      allow(controller).to receive(:render)
      expect(controller).to receive(:send_file)
      get :download_all, id: @fir.id

      expect(flash[:notices]).to eq(nil)
    end
  end

  describe "download_failed" do
    before :each do
      @fir = Factory(:file_import_result)
      @a = Factory(:attachment)
    end

    it "should delay if there are more than 200 records" do
      allow(FileImportResult).to receive(:delay).and_return(FileImportResult)
      expect(FileImportResult).to receive(:delay)
      allow_any_instance_of(FileImportResult).to receive(:change_records).and_return(["change_record"]*201)
      expect(FileImportResult).to receive(:download_results).with(false, @u.id, @fir.id, true)
      get :download_failed, id: @fir.id

      expect(flash[:notices].first).to eq("You will receive a system message when your file is finished processing.")
      expect(response).to be_redirect
    end

    it "should send the file immediately for less than 200 records" do
      allow_any_instance_of(FileImportResult).to receive(:change_records).and_return(["change_record"]*10)
      expect(FileImportResult).to receive(:download_results).with(false, @u.id, @fir).and_yield(Tempfile.new("file name"))
      allow(controller).to receive(:render)
      expect(controller).to receive(:send_file)
      get :download_failed, id: @fir.id

      expect(flash[:notices]).to eq(nil)
    end
  end
end
