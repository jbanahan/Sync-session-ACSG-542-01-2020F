require 'spec_helper'

describe OpenChain::ModelFieldDefinition::ShipmentFieldDefinition do
  describe "total cartons" do
    it "should total cartons without considering shipment lines" do
      s = Factory(:shipment)
      cs = Factory(:carton_set,shipment:s,carton_qty:4)
      cs2 = Factory(:carton_set,shipment:s,carton_qty:3)

      #2 shipment lines in the same carton set shouldn't increase the number of cartson
      Factory(:shipment_line,carton_set:cs,shipment:s,quantity:10)
      Factory(:shipment_line,carton_set:cs,shipment:s,quantity:12)

      mf = ModelField.find_by_uid(:shp_total_cartons)
      expect(mf).to be_read_only
      expect(mf.process_export(s,nil,true)).to eq 7

      ss = SearchSetup.new(module_type:'Shipment',user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'shp_total_cartons',operator:'eq',value:'7')
      expect(ss.result_keys).to eq [s.id]
    end
  end
end