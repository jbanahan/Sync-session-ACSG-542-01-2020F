require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorAssignmentChangeComparator do
  describe "autoflow" do
    before :each do
      cdefs = described_class.prep_custom_definitions([:prodven_risk])
      @prodven_risk = cdefs[:prodven_risk]
      @base_data = '{"entity":{"core_module":"ProductVendorAssignment","record_id":10324,"model_fields":{"prodven_puid":"000000000010033741","prodven_ven_name":"0000009444","prodven_ven_syscode":"0000009444","PVRID":"PVRVAL"}}}'
      @base_data.gsub!(/PVRID/,@prodven_risk.model_field_uid.to_s)
    end
    it "should call autoflow comparator if risk level has changed and the new value is Auto-Flow" do
      old_h = JSON.parse @base_data
      new_h = JSON.parse @base_data.gsub(/PVRVAL/,'Auto-Flow')
      expect(described_class).to receive(:get_json_hash).with('ob','op','ov').and_return old_h
      expect(described_class).to receive(:get_json_hash).with('nb','np','nv').and_return new_h

      @ord1 = double('Order')
      @ord2 = double('Order')
      expect(described_class).to receive(:find_linked_orders).with(1).and_return([@ord1,@ord2])

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).to receive(:process).with(@ord1)
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).to receive(:process).with(@ord2)

      described_class.compare 'ProductVendorAssignment', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'

    end
    it "should call autoflow comparator if risk level has changed and the old value has Auto-Flow in it" do
      old_h = JSON.parse @base_data.gsub(/PVRVAL/,'Some Sort of Auto-Flow')
      new_h = JSON.parse @base_data
      expect(described_class).to receive(:get_json_hash).with('ob','op','ov').and_return old_h
      expect(described_class).to receive(:get_json_hash).with('nb','np','nv').and_return new_h

      @ord1 = double('Order')
      @ord2 = double('Order')
      expect(described_class).to receive(:find_linked_orders).with(1).and_return([@ord1,@ord2])

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).to receive(:process).with(@ord1)
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).to receive(:process).with(@ord2)

      described_class.compare 'ProductVendorAssignment', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'

    end
    it "should not call autoflow comparator if risk level has not changed" do
      old_h = JSON.parse @base_data.gsub(/PVRVAL/,'Auto-Flow')
      new_h = JSON.parse @base_data.gsub(/PVRVAL/,'Auto-Flow')
      expect(described_class).to receive(:get_json_hash).with('ob','op','ov').and_return old_h
      expect(described_class).to receive(:get_json_hash).with('nb','np','nv').and_return new_h

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).not_to receive(:process)

      described_class.compare 'ProductVendorAssignment', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
  end
  describe "find_linked_orders" do
    it "should find linked orders" do
      p = Factory(:product)
      v = Factory(:company)
      pva = p.product_vendor_assignments.create!(vendor_id:v.id)
      ol = Factory(:order_line,product:p,order:Factory(:order,vendor:v))
      # an order without this product for the same vendor
      Factory(:order_line,order:Factory(:order,vendor:v))

      other_vendor = Factory(:company)
      p.product_vendor_assignments.create!(vendor_id:other_vendor.id)
      # an order for this product for a different vendor
      Factory(:order_line,product:p,order:Factory(:order,vendor:other_vendor))

      expect(described_class.find_linked_orders(pva.id).to_a).to eq [ol.order]
    end
  end
  describe '#get_json_hash' do
    it 'should exist on object' do
      # confirming that we're extending the right module to get the get_json_hash method
      expect(described_class.methods).to include(:get_json_hash)
    end
  end
end
