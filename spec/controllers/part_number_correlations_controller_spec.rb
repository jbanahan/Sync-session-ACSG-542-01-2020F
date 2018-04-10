require 'spec_helper'

describe PartNumberCorrelationsController do

  describe "create" do
    before :each do
      @u = Factory(:admin_user)
      sign_in_as @u
      @file = fixture_file_upload('/files/some_products.xls',"application/vnd.ms-excel")
    end

    it "should create a new PNC" do
      allow(PartNumberCorrelation).to receive(:can_view?).and_return(true)
      post :create, part_number_correlation: {starting_row: 1, part_column: "B", part_regex: "", importer_ids: ["1","2","3"], entry_country_iso: "US", attachment: @file}
      expect(response).to be_redirect
      expect(flash[:notices].first).to eq("Your file is being processed. You will receive a system notification when processing is complete.")
      @pnc = PartNumberCorrelation.last

      expect(@pnc.starting_row).to eq(1)
      expect(@pnc.part_column).to eq("B")
      expect(@pnc.part_regex).to eq("")
      expect(@pnc.entry_country_iso).to eq("US")
      expect(@pnc.attachment).not_to be_nil
    end

    it "should add a delayed job" do
      allow(PartNumberCorrelation).to receive(:can_view?).and_return(true)
      post :create, part_number_correlation: {starting_row: 1, part_column: "B", part_regex: "", importer_ids: ["1","2","3"], entry_country_iso: "US", attachment: @file}
      expect(Delayed::Job.all.length).to eq(1)
    end

    it "should redirect if no permission" do
      post :create, part_number_correlation: {starting_row: 2, part_column: "C", part_regex: "", importer_ids: ["1","2","3"], entry_country_iso: "CA", attachment: @file}
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("You do not have permission to use this tool.")
    end

    it "should redirect and show error on exceptions" do
      allow_any_instance_of(PartNumberCorrelation).to receive(:save).and_return(false)
      allow(PartNumberCorrelation).to receive(:can_view?).and_return(true)
      post :create, part_number_correlation: {starting_row: 3, part_column: "D", part_regex: "", importer_ids: ["1","2","3"], entry_country_iso: "US", attachment: @file}
      expect(response).to be_redirect
      expect(flash[:errors].first).to match("Please refresh the page and try again.")
    end
  end

  describe "index" do
    before :each do
      @u = Factory(:admin_user)
      sign_in_as @u
      @file = fixture_file_upload('/files/some_products.xls',"application/vnd.ms-excel")
    end

    it "should render if you have permission" do
      allow(PartNumberCorrelation).to receive(:can_view?).and_return(true)
      get :index
      expect(response).to be_success
    end

    it "should redirect if no permission" do
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("You do not have permission to use this tool.")
    end
  end
end
