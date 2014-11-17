require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJillSupport do
  before :each do
    @k = Class.new {extend OpenChain::CustomHandler::JJill::JJillSupport}
  end
  describe "get_product_category_from_vendor_styles" do
    it "should be Multi if multiple categories" do
      styles = ['KDR1234','ABC9491','KDR1291']
      expect(@k.get_product_category_from_vendor_styles styles).to eq 'Multi'
    end
    it "should be Other if not starting with 3 characters" do
      styles = ['1291BAD','1291BAD','1291BAD']
      expect(@k.get_product_category_from_vendor_styles styles).to eq 'Other'
    end
    it "should be first 3 characters if all the same" do
      styles = ['KDR1234','KDR9491','KDR1291']
      expect(@k.get_product_category_from_vendor_styles styles).to eq 'KDR'
    end
  end

  describe "generate_order_fingerprint" do
    it "should make fingerprint" do
      o = Order.new(customer_order_number:'ABC',
        vendor_id:7,
        mode:'Ocean',
        fob_point:'JAKARTA',
        first_expected_delivery_date:Date.new(2014,10,10),
        ship_window_start:Date.new(2014,9,1),
        ship_window_end:Date.new(2014,9,2),
        factory_id:27
      )
      cust_val = double('CustomValue')
      cust_val.should_receive(:value).and_return 'Boat'
      o.should_receive(:get_custom_value).with(instance_of CustomDefinition).and_return cust_val
      o.order_lines.build(quantity:10,price_per_unit:40,sku:'ABCDEF')
      o.order_lines.build(quantity:11,price_per_unit:41,sku:'ABCDEFG')

      expected_base = "ABC7BoatOceanJAKARTA27#{Date.new(2014,10,10).to_s}#{Date.new(2014,9,1).to_s}#{Date.new(2014,9,2).to_s}10.040.0ABCDEF11.041.0ABCDEFG"

      expect(@k.generate_order_fingerprint(o)).to eq Digest::MD5.hexdigest(expected_base)
    end
  end
end