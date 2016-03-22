require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter do
  describe :set_defaults do
    before :each do
      @cdefs = described_class.prep_custom_definitions([:cmp_default_inco_term,:cmp_default_handover_port,:cmp_default_country_of_origin,:ord_country_of_origin])
      @vendor = Factory(:company)
      @order = Factory(:order,vendor:@vendor)
    end
    it "should set default FOB Point" do
      @vendor.update_custom_value!(@cdefs[:cmp_default_handover_port],'Shanghai')
      expect{described_class.set_defaults(@order)}.to change(EntitySnapshot,:count).from(0).to(1)
      @order.reload
      expect(@order.fob_point).to eq 'Shanghai'
    end
    it "should set default INCO Term" do
      @vendor.update_custom_value!(@cdefs[:cmp_default_inco_term],'FOB')
      expect{described_class.set_defaults(@order)}.to change(EntitySnapshot,:count).from(0).to(1)
      @order.reload
      expect(@order.terms_of_sale).to eq 'FOB'
    end
    it "should set default Country of Origin" do
      @vendor.update_custom_value!(@cdefs[:cmp_default_country_of_origin],'CN')
      expect{described_class.set_defaults(@order)}.to change(EntitySnapshot,:count).from(0).to(1)
      @order.reload
      expect(@order.get_custom_value(@cdefs[:ord_country_of_origin]).value).to eq 'CN'
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
