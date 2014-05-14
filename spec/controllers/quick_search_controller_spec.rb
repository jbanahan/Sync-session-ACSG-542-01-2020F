require 'spec_helper'

describe QuickSearchController do
  before :each do 
    MasterSetup.get.update_attributes(:entry_enabled=>true)
    c = Factory(:company,:master=>true)
    @u = Factory(:user,:entry_view=>true,:company=>c)

    sign_in_as @u
  end

  describe "module_result" do
    it "should return a result" do
      ent = Factory(:entry,:entry_number=>'12345678901')
      mfid = "ent_entry_num"
      get :module_result, :mfid=>mfid, :v=>'123'
      response.should be_success
      r = JSON.parse response.body
      r["rows"].should have(1).item
      r["rows"].first["id"].should == ent.id
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
