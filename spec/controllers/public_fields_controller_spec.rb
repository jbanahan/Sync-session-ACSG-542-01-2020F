require 'spec_helper'

describe PublicFieldsController do
  before :each do
    @u = Factory(:user,:admin=>true)
    activate_authlogic
    UserSession.create! @u
  end
  describe "index" do
    it "should reject if not admin" do
      User.any_instance.stub(:admin?).and_return(false)
      get :index
      response.should redirect_to request.referrer
    end
    it "should show entry header fields" do
      get :index
      fields = assigns(:model_fields)
      fields.size.should == CoreModule::ENTRY.model_fields.size
      fields.each {|f| f.core_module.should == CoreModule::ENTRY}
    end
  end
  describe "save" do
    it "should reject if not admin" do
      User.any_instance.stub(:admin?).and_return(false)
      ph = {"public_fields"=>{"0"=>{"model_field_uid"=>"ent_ent_num"},"1"=>{"model_field_uid"=>"ent_entry_date"}}}
      post :save, ph
      response.should redirect_to request.referrer
    end
    it "should clear existing public fields" do
      PublicField.create!(:model_field_uid=>:ord_ord_num)
      ph = {"public_fields"=>{"0"=>{"model_field_uid"=>"ent_ent_num"},"1"=>{"model_field_uid"=>"ent_entry_date"}}}
      post :save, ph
      response.should redirect_to public_fields_path
      PublicField.all.should have(2).items
      PublicField.all.collect {|pf| pf.model_field_uid}.should == ["ent_ent_num","ent_entry_date"]
    end
  end
end
