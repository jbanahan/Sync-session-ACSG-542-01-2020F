require 'spec_helper'

describe Api::V1::ShipmentsController do
  before(:each) do
    MasterSetup.get.update_attributes(shipment_enabled:true)
    @u = Factory(:master_user,shipment_edit:true,shipment_view:true)
    allow_api_access @u
  end

  describe "index" do
    it "should find shipments" do
      s1 = Factory(:shipment,reference:'123')
      s2 = Factory(:shipment,reference:'ABC')
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].collect{|r| r['shp_ref']}).to eq ['123','ABC']
    end
  end

  describe "show" do
    it "should render shipment" do
      s = Factory(:shipment,reference:'123',mode:'Air')
      get :show, id: s.id
      expect(response).to be_success
      j = JSON.parse response.body
      sj = j['shipment']
      expect(sj['shp_ref']).to eq '123'
      expect(sj['shp_mode']).to eq 'Air'
    end
    it "should render custom values" do
      cd = Factory(:custom_definition,module_type:'Shipment',data_type:'string')
      s = Factory(:shipment)
      s.update_custom_value! cd, 'myval'
      get :show, id: s.id
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['shipment']["*cf_#{cd.id}"]).to eq 'myval'
    end
    it "should render shipment lines" do
      sl = Factory(:shipment_line,line_number:5,quantity:10)
      get :show, id: sl.shipment_id
      expect(response).to be_success
      j = JSON.parse response.body
      slj = j['shipment']['lines'].first
      expect(slj['id']).to eq sl.id
      expect(slj['shpln_line_number']).to eq 5
      expect(slj['shpln_shipped_qty']).to eq '10.0'
    end
    it "should render shipment containers" do
      c = Factory(:container,entry:nil,shipment:Factory(:shipment),
        container_number:'CN1234')
      sl = Factory(:shipment_line,shipment:c.shipment,container:c)
      get :show, id: sl.shipment_id
      expect(response).to be_success
      j = JSON.parse response.body
      slc = j['shipment']['containers'].first
      expect(slc['con_container_number']).to eq 'CN1234'
      expect(j['shipment']['lines'][0]['shpln_container_uid']).to eq c.id
    end
  end
end