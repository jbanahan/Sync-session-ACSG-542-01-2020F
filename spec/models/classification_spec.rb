require 'spec_helper'

describe Classification do
  describe 'classified?' do
    before :each do
      @c = Factory(:classification)
    end
    it "should return true for classified classification" do
      @c.tariff_records.create!(:hts_1=>'12345678')
      @c.should be_classified
    end
    it "should return false if no tariff records" do
      @c.should_not be_classified
    end
    it "should return false if tariff records don't have HTS" do
      @c.tariff_records.create!
      @c.should_not be_classified
    end
  end
  describe 'find_same' do
    it 'should return nil when no matches' do
      c = Factory(:classification)
      c.find_same.should be_nil
    end
    it 'should return the match when there is one' do
      c = Factory(:classification)
      new_one = Classification.new(:product_id=>c.product_id,:country_id=>c.country_id)
      new_one.find_same.should == c
    end
    it 'should ignore instant_classification children for matching purposes' do
      c = Factory(:classification,:instant_classification_id=>1)
      new_one = Classification.new(:product_id=>c.product_id,:country_id=>c.country_id)
      new_one.find_same.should be_nil
    end
  end
end
