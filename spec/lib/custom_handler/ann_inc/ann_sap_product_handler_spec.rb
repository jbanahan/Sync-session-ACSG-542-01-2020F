require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnSapProductHandler do
  
  def default_values 
    {
      :po=>'PO123',
      :style=>'123456',
      :name=>'Prod Name',
      :origin=>'CN',
      :import=>'US',
      :unit_cost=>'1.23',
      :ac_date=>'06/25/2013',
      :merch_dept_num=>'11',
      :merch_dept_name=>'MDN',
      :proposed_hts=>'1234567890',
      :proposed_long_description=>'P Long Desc',
      :fw=>'X',
      :import_indicator=>'X',
      :inco_terms=>'FOB',
      :missy=>'mstyle',
      :petite=>'pstyle',
      :tall=>'tstyle',
      :season=>'Fall13',
      :article_type=>'MyType'
    }
  end
  def make_row overrides={}
    h = default_values.merge overrides
    [:po,:style,:name,:origin,:import,:unit_cost,:ac_date,
      :merch_dept_num,:merch_dept_name,:proposed_hts,:proposed_long_description,
      :fw,:import_indicator,:inco_terms,:missy,:petite,:tall,:season,
      :article_type].collect {|k| h[k]}.to_csv.gsub(',','|')
  end
  before :all do
    @h = described_class.new
  end
  after :all do
    CustomDefinition.destroy_all
  end
  before :each do
    @us = Factory(:country,:iso_code=>'US',:import_location=>true)
    @good_hts = OfficialTariff.create(:hts_code=>'1234567890',:country=>@us)
    @user = Factory(:user)
    helper_class = Class.new do
      include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
    end
    @helper = helper_class.new
    @cdefs = @helper.prep_custom_definitions [:po,:origin,:import,:cost,
        :ac_date,:dept_num,:dept_name,:prop_hts,:prop_long,:oga_flag,:imp_flag,
        :inco_terms,:missy,:petite,:tall,:season,:article,:approved_long,
        :first_sap_date,:last_sap_date,:sap_revised_date
      ]
  end
  it "should create custom fields" do 
    CustomDefinition.where(:label=>"PO Numbers",:data_type=>:text,:module_type=>"Product",:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Origin Countries",:data_type=>:text,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Import Countries",:data_type=>:text,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Unit Costs",:data_type=>:text,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Earliest AC Date",:data_type=>:date,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Merch Dept Number",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Merch Dept Name",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Proposed HTS",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Proposed Long Description",:data_type=>:text,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Other Agency Flag",:data_type=>:boolean,:module_type=>'Classification',:read_only=>false).first.should_not be_nil
    CustomDefinition.where(:label=>"SAP Import Flag",:data_type=>:boolean,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"INCO Terms",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Missy Style",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Petite Style",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Tall Style",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Season",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Article Type",:data_type=>:string,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Approved Long Description",:data_type=>:text,:module_type=>'Product',:read_only=>false).first.should_not be_nil
    CustomDefinition.where(:label=>"First SAP Received Date",:data_type=>:date,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"Last SAP Received Date",:data_type=>:date,:module_type=>'Product',:read_only=>true).first.should_not be_nil
    CustomDefinition.where(:label=>"SAP Revised Date",:data_type=>:date,:module_type=>'Product',:read_only=>true).first.should_not be_nil
  end
  it "should create new product" do
    data = make_row
    @h.process data, @user
    Product.count.should == 1 
    p = Product.first
    h = default_values
    p.unique_identifier.should == h[:style]
    p.name.should == h[:name]
    p.get_custom_value(@cdefs[:po]).value.should == h[:po]
    p.get_custom_value(@cdefs[:origin]).value.should == h[:origin]
    p.get_custom_value(@cdefs[:import]).value.should == h[:import]
    p.get_custom_value(@cdefs[:cost]).value.should == h[:unit_cost]
    p.get_custom_value(@cdefs[:ac_date]).value.strftime("%m/%d/%Y").should == h[:ac_date]
    p.get_custom_value(@cdefs[:dept_num]).value.should == h[:merch_dept_num]
    p.get_custom_value(@cdefs[:dept_name]).value.should == h[:merch_dept_name]
    p.get_custom_value(@cdefs[:prop_hts]).value.should == h[:proposed_hts]
    p.get_custom_value(@cdefs[:prop_long]).value.should == h[:proposed_long_description]
    p.get_custom_value(@cdefs[:imp_flag]).value.should == ( h[:import_indicator] == 'X')
    p.get_custom_value(@cdefs[:inco_terms]).value.should == h[:inco_terms]
    p.get_custom_value(@cdefs[:missy]).value.should == h[:missy]
    p.get_custom_value(@cdefs[:petite]).value.should == h[:petite]
    p.get_custom_value(@cdefs[:tall]).value.should == h[:tall]
    p.get_custom_value(@cdefs[:season]).value.should == h[:season]
    p.get_custom_value(@cdefs[:article]).value.should == h[:article_type]
    p.get_custom_value(@cdefs[:approved_long]).value.should == h[:proposed_long_description]
    p.get_custom_value(@cdefs[:first_sap_date]).value.strftime("%y%m%d").should == 0.days.ago.strftime("%y%m%d")
    p.get_custom_value(@cdefs[:last_sap_date]).value.strftime("%y%m%d").should == 0.days.ago.strftime("%y%m%d")
    p.get_custom_value(@cdefs[:sap_revised_date]).value.should be_nil
    p.should have(1).classifications
    cls = p.classifications.find_by_country_id @us.id
    cls.get_custom_value(@cdefs[:oga_flag]).value.should == (h[:fw]=='X')
    cls.should have(1).tariff_records
    tr = cls.tariff_records.first
    tr.hts_1.should == '1234567890'
  end
  it "should set sap revised date if key field changes" do
    h = default_values
    p = Factory(:product,unique_identifier:h[:style])
    p.update_custom_value! @cdefs[:missy], 'oldvalue'
    @h.process make_row, @user
    p = Product.find p.id
    p.get_custom_value(@cdefs[:sap_revised_date]).value.strftime("%y%m%d").should == 0.days.ago.strftime("%y%m%d")
  end
  it "should not set sap revised date if no key fields change" do
    h = default_values
    @h.process make_row, @user
    p = Product.first
    p.update_custom_value! @cdefs[:sap_revised_date], 1.year.ago
    @h.process make_row, @user
    p = Product.find p.id
    p.get_custom_value(@cdefs[:sap_revised_date]).value.should == 1.year.ago.to_date
  end
  it "should not set hts number if not valid" do
    data = make_row(:proposed_hts=>'655432198')
    @h.process data, @user 
    Product.first.classifications.first.tariff_records.first.hts_1.should be_blank
  end
  it "should not create classification if country is not import_location?" do
    cn = Factory(:country,:iso_code=>'CN')
    data = make_row(:import=>', @userCN')
    @h.process data, @user
    Product.first.classifications.should be_empty
  end
  it "should find earliest AC Date" do
    data = make_row(:ac_date=>'12/29/2013')
    data << make_row(:ac_date=>'12/28/2013')
    data << make_row(:ac_date=>'12/23/2014')
    @h.process data, @user
    Product.first.get_custom_value(@cdefs[:ac_date]).value.strftime("%m/%d/%Y").should == "12/28/2013"
  end
  it "should aggregate values" do
    data = make_row(:unit_cost=>'10.11')
    data << make_row(:unit_cost=>'12.21')
    data << make_row(:unit_cost=>'6.14')
    data << make_row(:unit_cost=>'6.14')
    @h.process data, @user
    Product.first.get_custom_value(@cdefs[:cost]).value.should == "10.11\n12.21\n6.14"
  end
  it "should set hts for multiple countries" do
    cn = Factory(:country,:iso_code=>'CN',:import_location=>true)
    ot = cn.official_tariffs.create!(:hts_code=>'9876543210')
    data = make_row
    data << make_row(:import=>'CN',:proposed_hts=>ot.hts_code)
    @h.process data, @user
    p = Product.first
    p.should have(2).classifications
    p.classifications.find_by_country_id(@us.id).tariff_records.first.hts_1.should == '1234567890'
    p.classifications.find_by_country_id(cn.id).tariff_records.first.hts_1.should == ot.hts_code
  end
  it "should not override actual hts if proposed changes" do
    p = Factory(:product,:unique_identifier=>default_values[:style])
    p.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>'1111111111')
    @h.process make_row, @user
    p.reload
    p.should have(1).classifications
    p.classifications.first.should have(1).tariff_records
    p.classifications.first.tariff_records.first.hts_1.should == '1111111111'
  end
  it "should not override actual long description if proposed change" do
    p = Factory(:product,:unique_identifier=>default_values[:style])
    p.update_custom_value! @cdefs[:approved_long], 'something'
    @h.process make_row, @user
    p = Product.first
    p.get_custom_value(@cdefs[:approved_long]).value.should == 'something'
  end
  it "should handle multiple products" do
    h = default_values
    data = make_row
    data << make_row(:style=>'STY2',:ac_date=>'10/30/2015')
    @h.process data, @user
    Product.count.should == 2
    p1 = Product.find_by_unique_identifier(h[:style])
    p1.get_custom_value(@cdefs[:ac_date]).value.strftime("%m/%d/%Y").should == h[:ac_date]
    p2 = Product.find_by_unique_identifier('STY2')
    p2.get_custom_value(@cdefs[:ac_date]).value.strftime("%m/%d/%Y").should == '10/30/2015'
  end
  it "should create snapshot" do
    @h.process make_row, @user
    p = Product.first
    p.should have(1).entity_snapshots
    p.entity_snapshots.first.user.should == @user
  end
  it "should update last sap sent date but not first sap sent date" do
    p = Factory(:product,:unique_identifier=>default_values[:style])
    p.update_custom_value! @cdefs[:first_sap_date], Date.new(2012,4,10)
    p.update_custom_value! @cdefs[:last_sap_date], Date.new(2012,4,15)
    @h.process make_row, @user
    p = Product.first
    p.get_custom_value(@cdefs[:first_sap_date]).value.should == Date.new(2012,4,10)
    p.get_custom_value(@cdefs[:last_sap_date]).value.strftime("%y%m%d").should == 0.days.ago.strftime("%y%m%d")
  end
  it "should set import indicator and fw flag to false if value is not 'X'" do
    row = make_row :fw=>"", :import_indicator=>"a"
    @h.process row, @user
    p = Product.first
    p.get_custom_value(@cdefs[:imp_flag]).value.should be_false
    cls = p.classifications.find_by_country_id @us.id
    cls.get_custom_value(@cdefs[:oga_flag]).value.should be_false
  end
end
