require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJillSupport do
  describe "get_product_category_from_vendor_styles" do
    before :each do
      @k = Class.new {extend OpenChain::CustomHandler::JJill::JJillSupport}
    end
    it "should be Other if multiple categories" do
      styles = ['K123','W123','K123']
      expect(@k.get_product_category_from_vendor_styles styles).to eq 'Other'
    end
    it "should be Knit if all styles start with K" do
      styles = ['K123','K123']
      expect(@k.get_product_category_from_vendor_styles styles).to eq 'Knit'
    end
    it "should be Woven if all styles start with W" do
      styles = ['W345','W123']
      expect(@k.get_product_category_from_vendor_styles styles).to eq 'Woven'
    end
    it "should be Sweater if all styles start with S" do
      styles = ['S444','S419312']
      expect(@k.get_product_category_from_vendor_styles styles).to eq 'Sweater'
    end
    it "should be Other if all styles start with an unknown letter" do
      styles = ['Q12','QQQQZ']
      expect(@k.get_product_category_from_vendor_styles styles).to eq 'Other'
    end
  end
end