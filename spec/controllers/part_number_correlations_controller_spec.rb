require 'spec_helper'

describe PartNumberCorrelationsController do

  describe :create do
    before :each do
      @u = Factory(:admin_user)
      sign_in_as @u
      @file = fixture_file_upload('/files/some_products.xls',"application/vnd.ms-excel")
    end

    it "should create a new PNC" do
      PartNumberCorrelation.stub(:can_view?).and_return(true)
      post :create, part_number_correlation: {starting_row: 1, part_column: "B", part_regex: "", importer_ids: ["1","2","3"], entry_country_iso: "US", attachment: @file}
      response.should be_redirect
      flash[:notices].first.should == "Your file is being processed. You will receive a system notification when processing is complete."
      @pnc = PartNumberCorrelation.last

      @pnc.starting_row.should == 1
      @pnc.part_column.should == "B"
      @pnc.part_regex.should == ""
      @pnc.entry_country_iso.should == "US"
      @pnc.attachment.should_not be_nil
    end

    it "should add a delayed job" do
      PartNumberCorrelation.stub(:can_view?).and_return(true)
      post :create, part_number_correlation: {starting_row: 1, part_column: "B", part_regex: "", importer_ids: ["1","2","3"], entry_country_iso: "US", attachment: @file}
      Delayed::Job.all.length.should == 1
    end

    it "should redirect if no permission" do
      post :create, part_number_correlation: {starting_row: 2, part_column: "C", part_regex: "", importer_ids: ["1","2","3"], entry_country_iso: "CA", attachment: @file}
      response.should be_redirect
      flash[:errors].first.should == "You do not have permission to use this tool."
    end

    it "should redirect and show error on exceptions" do
      PartNumberCorrelation.any_instance.stub(:save).and_return(false)
      PartNumberCorrelation.stub(:can_view?).and_return(true)
      post :create, part_number_correlation: {starting_row: 3, part_column: "D", part_regex: "", importer_ids: ["1","2","3"], entry_country_iso: "US", attachment: @file}
      response.should be_redirect
      flash[:errors].first.should match("Please refresh the page and try again.")
    end
  end

  describe :index do
    before :each do
      @u = Factory(:admin_user)
      sign_in_as @u
      @file = fixture_file_upload('/files/some_products.xls',"application/vnd.ms-excel")
    end

    it "should render if you have permission" do
      PartNumberCorrelation.stub(:can_view?).and_return(true)
      get :index
      response.should be_success
    end

    it "should redirect if no permission" do
      get :index
      response.should be_redirect
      flash[:errors].first.should == "You do not have permission to use this tool."
    end
  end
end