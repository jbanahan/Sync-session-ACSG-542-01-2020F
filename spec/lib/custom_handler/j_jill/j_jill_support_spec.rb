require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJillSupport do
  describe "get_product_category_from_vendor_styles" do
    before :each do
      @k = Class.new {extend OpenChain::CustomHandler::JJill::JJillSupport}
    end
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
end