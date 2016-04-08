require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderAcceptance do
  describe '#can_be_accepted?' do
    before :each do
      @cdefs = described_class.prep_custom_definitions([:ord_country_of_origin])
      @o = Factory(:order,fob_point:'Shanghai',terms_of_sale:'FOB')
      @o.update_custom_value!(@cdefs[:ord_country_of_origin],'CN')
    end
    it "should pass if fields are populated" do
      expect(described_class.can_be_accepted?(@o)).to be_true
    end
    it "should fail if FOB Point is empty" do
      @o.update_attributes(fob_point:nil)
      expect(described_class.can_be_accepted?(@o)).to be_false
    end
    it "should fail if INCO terms are empty" do
      @o.update_attributes(terms_of_sale:nil)
      expect(described_class.can_be_accepted?(@o)).to be_false
    end
    it "should fail if country of origin is empty" do
      @o.update_custom_value!(@cdefs[:ord_country_of_origin],'')
      expect(described_class.can_be_accepted?(@o)).to be_false
    end
  end
end
