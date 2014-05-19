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
      FileImportResult.any_instance.stub(:delay).and_return(@fir)
      FileImportResult.any_instance.stub(:change_records).and_return(["change_record"]*300)
      FileImportResult.any_instance.should_receive(:delay)
      FileImportResult.any_instance.should_receive(:download_results).with(true, @u.id, true)
      get :download_all, id: @fir.id

      flash[:notices].first.should == "You will receive a system message when your file is finished processing."
      response.should be_redirect
    end

    it "should send directly to attachment if less than 200 records" do
      FileImportResult.any_instance.stub(:change_records).and_return(["change_record"]*100)
      FileImportResult.any_instance.should_receive(:download_results).with(true, @u.id).and_return @a
      get :download_all, id: @fir.id

      flash[:notices].should == nil
      response.should be_redirect
      response.location.should == "http://test.host/attachments/#{@a.id}/download"
    end
  end

  describe :download_failed do
    before :each do 
      @fir = Factory(:file_import_result)
      @a = Factory(:attachment)
    end

    it "should delay if there are more than 200 records" do
      FileImportResult.any_instance.stub(:delay).and_return(@fir)
      FileImportResult.any_instance.stub(:change_records).and_return(["change_record"]*300)
      FileImportResult.any_instance.should_receive(:delay)
      FileImportResult.any_instance.should_receive(:download_results).with(false, @u.id, true)
      get :download_failed, id: @fir.id

      flash[:notices].first.should == "You will receive a system message when your file is finished processing."
      response.should be_redirect
    end

    it "should send directly to attachment if less than 200 records" do
      FileImportResult.any_instance.stub(:change_records).and_return(["change_record"]*100)
      FileImportResult.any_instance.should_receive(:download_results).with(false, @u.id).and_return @a
      get :download_failed, id: @fir.id

      flash[:notices].should == nil
      response.should be_redirect
      response.location.should == "http://test.host/attachments/#{@a.id}/download"
    end
  end
end