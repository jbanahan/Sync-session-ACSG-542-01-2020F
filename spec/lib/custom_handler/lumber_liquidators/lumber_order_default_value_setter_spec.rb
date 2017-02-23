require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter do
  describe "set_defaults" do
    before :each do
      @cdefs = described_class.prep_custom_definitions([:cmp_default_inco_term,:cmp_default_handover_port,:cmp_default_country_of_origin,:ord_country_of_origin])
      @vendor = Factory(:company)
      @order = Factory(:order,vendor:@vendor)
    end
    it "should set default FOB Point" do
      @vendor.update_custom_value!(@cdefs[:cmp_default_handover_port],'Shanghai')
      expect{described_class.set_defaults(@order)}.to change(EntitySnapshot,:count).from(0).to(1)
      expect(EntitySnapshot.first.context).to eq "System Job: Order Default Value Setter"
      @order.reload
      expect(@order.fob_point).to eq 'Shanghai'
    end
    it "should set default Country of Origin" do
      @vendor.update_custom_value!(@cdefs[:cmp_default_country_of_origin],'CN')
      expect{described_class.set_defaults(@order)}.to change(EntitySnapshot,:count).from(0).to(1)
      expect(EntitySnapshot.first.context).to eq "System Job: Order Default Value Setter"
      @order.reload
      expect(@order.get_custom_value(@cdefs[:ord_country_of_origin]).value).to eq 'CN'
    end
    context "ship_from" do
      it "should set the ship from if the vendor only has one shipping address" do
        a = Factory(:address,shipping:true,company:@vendor)
        @vendor.reload
        expect{described_class.set_defaults(@order)}.to change(EntitySnapshot,:count).from(0).to(1)
        expect(EntitySnapshot.first.context).to eq "System Job: Order Default Value Setter"
        @order.reload
        expect(@order.ship_from_id).to eq a.id
      end
      it "should not set the ship from if the vendor has multiple shipping addresses" do
        Factory(:address,shipping:true,company:@vendor)
        Factory(:address,shipping:true,company:@vendor)
        expect{described_class.set_defaults(@order)}.to_not change(EntitySnapshot,:count)
        @order.reload
        expect(@order.ship_from_id).to be_nil
      end
      it "should not fail if the vendor has no shipping addresses" do
        expect{described_class.set_defaults(@order)}.to_not change(EntitySnapshot,:count)
        @order.reload
        expect(@order.ship_from_id).to be_nil
      end

    end
    it "should not fail if vendor is nil" do
      o = Order.new
      expect{described_class.set_defaults(o)}.to_not change(EntitySnapshot,:count)
      expect(o.id).to be_nil
    end
    it "should not overwrite an existing value" do
      @order.update_attributes(fob_point: 'New York')
      @vendor.update_custom_value!(@cdefs[:cmp_default_handover_port],'Shanghai')
      expect{described_class.set_defaults(@order)}.to_not change(EntitySnapshot,:count)
      @order.reload
      expect(@order.fob_point).to eq 'New York'
    end
  end
end
