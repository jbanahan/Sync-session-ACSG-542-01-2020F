require 'spec_helper'

describe QuickSearchController do
  before :each do 
    MasterSetup.get.update_attributes(vendor_management_enabled: true, entry_enabled: true)
    c = Factory(:company,:master=>true)
    @u = Factory(:user, vendor_view: true, entry_view: true, company: c)

    sign_in_as @u
  end

  describe "module_result" do
    it "should return a result for Vendor" do
      vendor = Factory(:company, :name=>'Company', vendor: true, system_code: "CODE")
      mfid = "cmp_name"
      get :module_result, :mfid=>mfid, :v=>'Co'
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r["rows"].length).to eq 1
      row = r["rows"].first
      expect(row["id"]).to eq vendor.id
      expect(row["values"]).to eq ["Company", "CODE"]
      expect(row["link"]).to eq "/vendors/#{vendor.id}"
      expect(r["headings"]).to eq ["Name", "System Code"]
    end

    it "should return a result for Entry" do
      ent = Factory(:entry,:entry_number=>'12345678901', broker_reference: "REF", release_date: Time.zone.now)
      mfid = "ent_entry_num"
      get :module_result, :mfid=>mfid, :v=>'123'
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r["rows"].length).to eq 1
      row = r["rows"].first
      expect(row["id"]).to eq ent.id
      expect(row["values"]).to eq ["REF", "12345678901", ent.release_date.strftime("%Y-%m-%d %H:%M")]
      expect(row["link"]).to eq "/entries/#{ent.id}"
      expect(r["headings"]).to eq ["Broker Reference", "Entry Number", "Release Date"]
    end
  end

  context :show do 
    it "should put registered custom definitions into the quick search uid list" do
      cd_1 = Factory(:custom_definition, :module_type=>"Entry", :quick_searchable => true)
      cd_2 = Factory(:custom_definition, :module_type=>"Entry", :quick_searchable => false)

      ModelField.reset_custom_fields

      get :show, :v=>"Test"
      response.should be_success
      map = assigns :module_field_map

      # Make sure cd_1's uid is found in the map for Entries
      # Not entirely sure why using CoreModule::ENTRY results in not finding the model_field array
      # from the map (looks like it's something with the constant's namespace and dependency trees)
      map[CoreModule.find_by_class_name("Entry")].include?(cd_1.model_field_uid.to_sym).should be_true
      map[CoreModule.find_by_class_name("Entry")].include?(cd_2.model_field_uid.to_sym).should_not be_true
    end
  end

  context :module_result do
    it "should run a search and return a result for a custom defintion field" do
      cd_1 = Factory(:custom_definition, :module_type=>"Entry", :quick_searchable => true)
      e = Factory(:entry)

      e.update_custom_value! cd_1, "Test"

      get :module_result, :mfid=>cd_1.model_field_uid, :v=>"Test"
      response.should be_success
      result = JSON.parse(response.body)
      # Validate we got the entry back we were searching for
      result["rows"][0]["id"].should == e.id
    end
  end
end
