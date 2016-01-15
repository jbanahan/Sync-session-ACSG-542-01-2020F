require 'spec_helper'

describe "OrderLineFieldDefinition" do
  before :each do
    @mf = ModelField.find_by_uid(:ordln_total_cost)
  end
  describe "ordln_total_cost" do
    it "should round if total_cost_digits is populated" do
      # default extended cost 31830.4728, should round to 31830.47
      ol = Factory(:order_line,price_per_unit:1.89,quantity:16841.52,total_cost_digits:2)
      
      # test query
      ss = SearchSetup.new(module_type:'Order',user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ordln_total_cost',operator:'eq',value:'31830.47')
      expect(ss.result_keys).to eq [ol.order_id]

      # test in memory export value
      expect(@mf.process_export(ol,nil,true)).to eq 31830.47
    end
    it "should not round if total_cost_digits is not populated" do
      # default extended cost 31830.4728, should round to 31830.47
      ol = Factory(:order_line,price_per_unit:1.89,quantity:16841.52)

      # test query
      ss = SearchSetup.new(module_type:'Order',user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ordln_total_cost',operator:'eq',value:'31830.4728')
      expect(ss.result_keys).to eq [ol.order_id]

      # test in memory export value
      expect(@mf.process_export(ol,nil,true)).to eq 31830.4728
    end
  end
end