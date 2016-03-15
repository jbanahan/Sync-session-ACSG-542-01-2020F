require 'spec_helper'

describe "OrderFieldDefinition" do
  describe "ord_total_cost" do
    before :each do
      @mf = ModelField.find_by_uid(:ord_total_cost)
    end
    it "should total and round at line level" do
      # WELCOME TO HELL. 
      # In this example, each line calculates to 31830.4728, which means the unrounded total 
      # is 63660.9456 which would round to 63660.95, which is wrong
      #
      # If you round each line first and add them up, you will get 31830.47 * 2 = 63660.94, which 
      # is what we want

      ol1 = Factory(:order_line,price_per_unit:1.89,quantity:16841.52,total_cost_digits:2)
      ol2 = Factory(:order_line,order:ol1.order,price_per_unit:1.89,quantity:16841.52,total_cost_digits:2)

      # test query
      ss = SearchSetup.new(module_type:'Order',user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ord_total_cost',operator:'eq',value:'63660.94')
      expect(ss.result_keys).to eq [ol1.order_id]

      # test in memory export value
      expect(@mf.process_export(ol1.order,nil,true)).to eq 63660.94
    end
    it "should get exact cost when no rounding" do
      ol1 = Factory(:order_line,price_per_unit:1.89,quantity:16841.52)
      ol2 = Factory(:order_line,order:ol1.order,price_per_unit:1.89,quantity:16841.52)

      # test query
      ss = SearchSetup.new(module_type:'Order',user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ord_total_cost',operator:'eq',value:'63660.9456')
      expect(ss.result_keys).to eq [ol1.order_id]

      # test in memory export value
      expect(@mf.process_export(ol1.order,nil,true)).to eq 63660.9456
    end
  end
end