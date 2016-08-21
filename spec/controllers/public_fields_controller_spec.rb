require 'spec_helper'

describe PublicFieldsController do
  before :each do
    @u = Factory(:user,:admin=>true)

    sign_in_as @u
  end
  describe "index" do
    it "should reject if not admin" do
      allow_any_instance_of(User).to receive(:admin?).and_return(false)
      get :index
      expect(response).to redirect_to request.referrer
    end
    it "should show entry header fields" do
      get :index
      fields = assigns(:model_fields)
      expect(fields.size).to eq(CoreModule::ENTRY.model_fields.size)
      fields.each {|f| expect(f.core_module).to eq(CoreModule::ENTRY)}
    end
  end
  describe "save" do
    it "should reject if not admin" do
      allow_any_instance_of(User).to receive(:admin?).and_return(false)
      ph = {"public_fields"=>{"0"=>{"model_field_uid"=>"ent_ent_num"},"1"=>{"model_field_uid"=>"ent_entry_date"}}}
      post :save, ph
      expect(response).to redirect_to request.referrer
    end
    it "should clear existing public fields" do
      PublicField.create!(:model_field_uid=>:ord_ord_num)
      ph = {"public_fields"=>{"0"=>{"model_field_uid"=>"ent_ent_num"},"1"=>{"model_field_uid"=>"ent_entry_date"}}}
      post :save, ph
      expect(response).to redirect_to public_fields_path
      expect(PublicField.all.size).to eq(2)
      expect(PublicField.all.collect {|pf| pf.model_field_uid}).to eq(["ent_ent_num","ent_entry_date"])
    end
  end
end
