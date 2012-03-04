require 'spec_helper'

describe ModelFieldsController do
  it "should filter fields w/o permission" do
    u = Factory(:user)
    activate_authlogic
    UserSession.create! u
    get :find_by_module_type, :module_type=>"Entry"
    r = JSON.parse response.body
    found_uids = r.collect {|mf| mf["uid"]}
    found_uids.should_not include("ent_broker_invoice_total")
  end
  it "should include fields w permission" do
    MasterSetup.get.update_attributes(:broker_invoice_enabled=>true)
    u = Factory(:user,:company=>Factory(:company,:master=>true),:broker_invoice_view=>true)
    activate_authlogic
    UserSession.create! u
    get :find_by_module_type, :module_type=>"Entry"
    r = JSON.parse response.body
    found_uids = r.collect {|mf| mf["uid"]}
    found_uids.should include("ent_broker_invoice_total")
  end
end
