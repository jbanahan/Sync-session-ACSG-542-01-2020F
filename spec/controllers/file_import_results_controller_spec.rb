require 'spec_helper'

describe FileImportResultsController do
  before :each do
    @u = Factory(:admin_user)
    sign_in_as @u
  end

  describe :download_all do
    before :each do 
      @fir = Factory(:file_import_result)
      @a = Factory(:attachment)
    end

    it "should delay if there are more than 200 records" do
      FileImportResult.stub(:delay).and_return(FileImportResult)
      FileImportResult.should_receive(:delay)
      FileImportResult.any_instance.stub(:change_records).and_return(["change_record"]*201)
      FileImportResult.should_receive(:download_results).with(true, @u.id, @fir.id, true)
      get :download_all, id: @fir.id

      flash[:notices].first.should == "You will receive a system message when your file is finished processing."
      response.should be_redirect
    end

    it "should send the file immediately for less than 200 records" do
      FileImportResult.any_instance.stub(:change_records).and_return(["change_record"]*10)
      FileImportResult.should_receive(:download_results).with(true, @u.id, @fir).and_yield(Tempfile.new("file name"))
      controller.stub!(:render)
      controller.should_receive(:send_file)
      get :download_all, id: @fir.id

      flash[:notices].should == nil
    end
  end

  describe :download_failed do
    before :each do 
      @fir = Factory(:file_import_result)
      @a = Factory(:attachment)
    end

    it "should delay if there are more than 200 records" do
      FileImportResult.stub(:delay).and_return(FileImportResult)
      FileImportResult.should_receive(:delay)
      FileImportResult.any_instance.stub(:change_records).and_return(["change_record"]*201)
      FileImportResult.should_receive(:download_results).with(false, @u.id, @fir.id, true)
      get :download_failed, id: @fir.id

      flash[:notices].first.should == "You will receive a system message when your file is finished processing."
      response.should be_redirect
    end

    it "should send the file immediately for less than 200 records" do
      FileImportResult.any_instance.stub(:change_records).and_return(["change_record"]*10)
      FileImportResult.should_receive(:download_results).with(false, @u.id, @fir).and_yield(Tempfile.new("file name"))
      controller.stub!(:render)
      controller.should_receive(:send_file)
      get :download_failed, id: @fir.id

      flash[:notices].should == nil
    end
  end
end