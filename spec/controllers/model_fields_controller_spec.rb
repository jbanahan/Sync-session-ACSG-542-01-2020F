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

  describe "glossary" do
    render_views

    before :each do
      @mf = ModelField.new(10000,:test,CoreModule::PRODUCT,:name)
    end

    it "should return product model fields with the proper label" do
      u = Factory(:user)
      activate_authlogic
      UserSession.create! u

      get :glossary, {core_module: 'Product'}
      expect(response).to be_success
      assigns(:fields).length.should > 0
      assigns(:label).should == "Product"
    end

    it "should display the module not found page for nil modules" do
      u = Factory(:user)
      activate_authlogic
      UserSession.create! u

      get :glossary, {core_module: 'nonexistent'}
      expect(response).to be_success
      response.body.should =~ /We were unable to locate the glossary you requested/
    end

    it "should redirect for users who aren't logged in" do
      get :glossary, {core_module: 'doesnt_matter'}
      response.status.should == 302
    end
  end
end
