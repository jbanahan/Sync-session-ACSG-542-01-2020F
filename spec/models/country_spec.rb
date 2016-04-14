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
      Country.find_by_iso_code('IT').european_union?.should be_true
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
  describe :quicksearch_only_for_import_locations do
    it "validates that if quicksearch_view is enabled import_location is also set" do
      Country.load_default_countries
      c = Country.first
      c.quicksearch_show = true
      expect(c.valid?).to eq false
      expect(c.errors).to have_key :quicksearch_show
    end
  end
end
