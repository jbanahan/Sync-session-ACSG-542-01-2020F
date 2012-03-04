require 'spec_helper'

describe QuickSearchController do
  before :each do 
    MasterSetup.get.update_attributes(:entry_enabled=>true)
    c = Factory(:company,:master=>true)
    @u = Factory(:user,:entry_view=>true,:company=>c)
    activate_authlogic
    UserSession.create! @u
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
end
