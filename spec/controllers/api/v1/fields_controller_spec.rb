require 'spec_helper'

describe Api::V1::FieldsController do
  before(:each) do
    MasterSetup.get.update_attributes(shipment_enabled:true)
    @u = Factory(:master_user,shipment_view:true)
    allow_api_access @u
  end

  describe "index" do
    it "should return a module" do
      get :index, module_types: 'shipment'
      expect(response).to be_success
      j = JSON.parse response.body
      mf = ModelField.find_by_uid :shp_ref
      found = j['shipment_fields'].find {|f| f['uid']=='shp_ref'}
      expected = {'uid'=>'shp_ref','label'=>mf.label,'data_type'=>mf.data_type.to_s}
      expect(found).to eql expected
    end
    it "should return multiple modules" do
      get :index, module_types: 'shipment,shipment_line'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['shipment_fields'].find {|f| f['uid']=='shp_ref'}).to_not be_nil
      expect(j['shipment_line_fields'].find {|f| f['uid']=='shpln_line_number'}).to_not be_nil
    end
    it "should fail on bad module" do
      get :index, module_types: 'shipment,other'
      expect(response.status).to eq 400
    end
    it "should fail on module that user cannot view" do
      get :index, module_types: 'order'
      expect(response.status).to eq 401
    end
  end
end