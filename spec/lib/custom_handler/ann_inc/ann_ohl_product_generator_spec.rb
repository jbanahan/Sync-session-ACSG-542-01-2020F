require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnOhlProductGenerator do
  before :each do
    @us = Factory(:country,:iso_code=>'US')
    @ca = Factory(:country,:iso_code=>'CA')
    helper_class = Class.new do
      include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
    end
    @helper = helper_class.new
    @cdefs = @helper.prep_custom_definitions[:approved_date,:approved_long]
  end
  describe :sync_csv do
    it "should clean newlines from long description"
    it "should force capitalization of ISO codes"
    it "should use long description override from classification if it exists"
  end
  describe :query do
    it "should sort US then CA" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      [@ca,@us].each do |cntry|
        p.classifications.create!(:country_id=>cntry.id)
        fail 'not done'
      end
    end
    it "should not send products that aren't approved"
    it "should find product with US that needs sync"
    it "should find products with CA that need sync"
    it "should not send record with empty HTS"
    it "should not send other countries besides US & CA"
  end
  describe :ftp_credentials do
    it 'needs to be implemented'
  end
end
