require 'spec_helper'

describe FileImportResultsController do
  before :each do
    @u = Factory(:admin_user)
    sign_in_as @u
  end

  describe :download_results do
    before :each do
      @fir = Factory(:file_import_result)
      @cr1 = Factory(:change_record, file_import_result: @fir, failed: true)
      @cr2 = Factory(:change_record, file_import_result: @fir, failed: false)
      @cr3 = Factory(:change_record, file_import_result: @fir, failed: true)
    end
    it "should skip successful records when include_all is false" do
      File.any_instance.should_receive(:write).exactly(3).times
      get :download_failed, id: @fir.id
    end

    it "should include successful records when include_all is true" do
      File.any_instance.should_receive(:write).exactly(4).times
      get :download_all, id: @fir.id
    end
  end
end