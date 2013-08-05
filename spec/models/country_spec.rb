require 'spec_helper'

describe Country do
  it "should reload model field on save" do
    ModelField.should_receive(:reload).with(true)
    Country.create!(:name=>'MYC',:iso_code=>'YC')
  end
  describe :load_default_countries do
    it "should create countries" do
      Country.load_default_countries
      Country.scoped.count.should == Country::ALL_COUNTRIES.size
      Country.find_by_iso_code('VN').name.should == 'VIET NAM'
    end
    it "should not run if country count matches all countries" do
      Country.load_default_countries
      c = Country.find_by_iso_code('VN')
      c.name = "OVN"
      c.save!
      Country.load_default_countries
      Country.find_by_iso_code('VN').name.should == 'OVN'
    end
  end
end
