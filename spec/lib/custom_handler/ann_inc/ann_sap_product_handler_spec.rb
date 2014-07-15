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
      # Use a blank missy style by default, otherwise we trigger some unique_identifier update logic, which we don't care about in the common case
      :missy=>nil,
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
      :article_type].collect {|k| h[k]}.to_csv(:quote_char=>"\007",:col_sep=>'|')
  end
  before :all do
    @h = described_class.new
  end
  after :all do
    CustomDefinition.destroy_all
  end
  before :each do
    FieldValidatorRule.any_instance.stub :reset_model_fields
    @us = Factory(:country,:iso_code=>'US',:import_location=>true)
    @good_hts = OfficialTariff.create(:hts_code=>'1234567890',:country=>@us)
    @user = Factory(:user)
    @cdefs = described_class.prep_custom_definitions [:po,:origin,:import,:cost,
        :ac_date,:dept_num,:dept_name,:prop_hts,:prop_long,:oga_flag,:imp_flag,
        :inco_terms,:related_styles,:season,:article,:approved_long,
        :first_sap_date,:last_sap_date,:sap_revised_date, :maximum_cost, :minimum_cost
      ]
    ModelField.reload true
  end
  it "should create custom fields" do 
    read_onlys = []
    read_onlys << CustomDefinition.where(:label=>"PO Numbers",:data_type=>:text,:module_type=>"Product").first
    read_onlys << CustomDefinition.where(:label=>"Origin Countries",:data_type=>:text,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Import Countries",:data_type=>:text,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Unit Costs",:data_type=>:text,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Earliest AC Date",:data_type=>:date,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Merch Dept Number",:data_type=>:string,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Merch Dept Name",:data_type=>:string,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Proposed HTS",:data_type=>:string,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Proposed Long Description",:data_type=>:text,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"SAP Import Flag",:data_type=>:boolean,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"INCO Terms",:data_type=>:string,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Related Styles",:data_type=>:text,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Season",:data_type=>:string,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Article Type",:data_type=>:string,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"First SAP Received Date",:data_type=>:date,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Last SAP Received Date",:data_type=>:date,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"SAP Revised Date",:data_type=>:date,:module_type=>'Product').first
    read_onlys << CustomDefinition.where(:label=>"Minimum Cost",:data_type=>:decimal,:module_type=>'Classification').first
    read_onlys << CustomDefinition.where(:label=>"Maximum Cost",:data_type=>:decimal,:module_type=>'Classification').first
    CustomDefinition.where(:label=>"Other Agency Flag",:data_type=>:boolean,:module_type=>'Classification').first.should_not be_nil
    CustomDefinition.where(:label=>"Approved Long Description",:data_type=>:text,:module_type=>'Product').first.should_not be_nil
    read_onlys.each do |cd| 
      cd.model_field.should be_read_only
    end
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
    p.get_custom_value(@cdefs[:cost]).value.should == "#{h[:import]} - 0#{h[:unit_cost]}"
    p.get_custom_value(@cdefs[:ac_date]).value.strftime("%m/%d/%Y").should == h[:ac_date]
    p.get_custom_value(@cdefs[:dept_num]).value.should == h[:merch_dept_num]
    p.get_custom_value(@cdefs[:dept_name]).value.should == h[:merch_dept_name]
    p.get_custom_value(@cdefs[:prop_hts]).value.should == h[:proposed_hts]
    p.get_custom_value(@cdefs[:prop_long]).value.should == h[:proposed_long_description]
    p.get_custom_value(@cdefs[:imp_flag]).value.should == ( h[:import_indicator] == 'X')
    p.get_custom_value(@cdefs[:inco_terms]).value.should == h[:inco_terms]
    p.get_custom_value(@cdefs[:related_styles]).value.should == "#{h[:petite]}\n#{h[:tall]}"
    p.get_custom_value(@cdefs[:season]).value.should == h[:season]
    p.get_custom_value(@cdefs[:article]).value.should == h[:article_type]
    p.get_custom_value(@cdefs[:approved_long]).value.should == h[:proposed_long_description]
    p.get_custom_value(@cdefs[:first_sap_date]).value.should == 0.days.ago.to_date
    p.get_custom_value(@cdefs[:last_sap_date]).value.should == 0.days.ago.to_date
    p.get_custom_value(@cdefs[:sap_revised_date]).value.should == 0.days.ago.to_date
    p.should have(1).classifications
    cls = p.classifications.find_by_country_id @us.id
    cls.get_custom_value(@cdefs[:oga_flag]).value.should == (h[:fw]=='X')
    cls.get_custom_value(@cdefs[:maximum_cost]).value.should == BigDecimal.new(h[:unit_cost])
    cls.get_custom_value(@cdefs[:minimum_cost]).value.should == BigDecimal.new(h[:unit_cost])
    cls.should have(1).tariff_records
    tr = cls.tariff_records.first
    tr.hts_1.should == '1234567890'
  end

  it "should change sap revised date if key field changes" do
    h = default_values
    @h.process make_row, @user
    p = Product.first
    p.update_custom_value! @cdefs[:sap_revised_date], 1.year.ago
    p.update_custom_value! @cdefs[:origin], 'somethingelse'
    @h.process make_row, @user
    p = Product.find p.id
    p.get_custom_value(@cdefs[:sap_revised_date]).value.should == 0.days.ago.to_date
  end
  it "should not chage sap revised date if no key fields change" do
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
    data = make_row(:import=>'CN')
    @h.process data, @user
    Product.first.classifications.should be_empty
  end
  it "should pass with quotes in field" do
    @h.process '7073705|560120|s 3.0 and 3.1|CN|US|        10|07/25/2013|023|M Knits|3924905500| Ladies "batwing" top made of silk|||DDP||||ATS Perfect Pcs|ZNSC', @user
    Product.first.get_custom_value(@cdefs[:prop_long]).value.should == 'Ladies "batwing" top made of silk'
  end
  it "should find earliest AC Date" do
    data = make_row(:ac_date=>'12/29/2013')
    data << make_row(:ac_date=>'12/28/2013')
    data << make_row(:ac_date=>'12/23/2014')
    @h.process data, @user
    Product.first.get_custom_value(@cdefs[:ac_date]).value.strftime("%m/%d/%Y").should == "12/28/2013"
  end
  it "should aggregate unit cost by country" do
    data = make_row(:unit_cost=>'10.11',:import=>'CA')
    data << make_row(:unit_cost=>'12.21',:import=>'CA')
    data << make_row(:unit_cost=>'6.14',:import=>'CA')
    data << make_row(:unit_cost=>'6.14',:import=>'CA')
    data << make_row(:unit_cost=>'6.14',:import=>'US')
    @h.process data, @user
    Product.first.get_custom_value(@cdefs[:cost]).value.should == "US - 06.14\nCA - 12.21\nCA - 10.11\nCA - 06.14"
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
    data << make_row(:style=>'STY2',:ac_date=>'10/30/2015',:petite=>'p2',:tall=>'t2')
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
  it "should append aggregate value information into an existing record" do
    p = Factory(:product, :unique_identifier=> default_values[:style])
    p.update_custom_value! @cdefs[:po], "PO1"
    p.update_custom_value! @cdefs[:origin], "Origin1"
    p.update_custom_value! @cdefs[:import], "Import1"
    p.update_custom_value! @cdefs[:cost], "Import1 - 01.23"
    p.update_custom_value! @cdefs[:dept_num], "Dept1"
    p.update_custom_value! @cdefs[:dept_name], "Name1"

    row = make_row :po =>"PO2",:origin=>"Origin2",:import=>"Import2",:unit_cost=>2.0,:merch_dept_num=>"Dept2",:merch_dept_name=>"Name2"
    @h.process row, @user
    p = Product.first

    p.get_custom_value(@cdefs[:po]).value.should == "PO1\nPO2"
    p.get_custom_value(@cdefs[:origin]).value.should == "Origin1\nOrigin2"
    p.get_custom_value(@cdefs[:import]).value.should == "Import1\nImport2"
    p.get_custom_value(@cdefs[:cost]).value.should == "Import2 - 02.00\nImport1 - 01.23"
    p.get_custom_value(@cdefs[:dept_num]).value.should == "Dept1\nDept2"
    p.get_custom_value(@cdefs[:dept_name]).value.should == "Name1, Name2"
  end


  it "should normalize the unit cost to at least 2 decimal places and at least 4 significant digits" do
    @h.process make_row(:import=>"Import",:unit_cost=>"0"), @user 
    p = Product.first
    p.get_custom_value(@cdefs[:cost]).value.should == "Import - 00.00"

    @h.process make_row(:import=>"Import",:unit_cost=>"1"), @user 
    p = Product.first
    p.get_custom_value(@cdefs[:cost]).value.should == "Import - 01.00\nImport - 00.00"

    @h.process make_row(:import=>"Import",:unit_cost=>"2.0"), @user 
    p = Product.first
    p.get_custom_value(@cdefs[:cost]).value.should == "Import - 02.00\nImport - 01.00\nImport - 00.00"

    @h.process make_row(:import=>"Import",:unit_cost=>"12.00"), @user 
    p = Product.first
    p.get_custom_value(@cdefs[:cost]).value.should == "Import - 12.00\nImport - 02.00\nImport - 01.00\nImport - 00.00"

    @h.process make_row(:import=>"Import",:unit_cost=>"120.001"), @user 
    p = Product.first
    p.get_custom_value(@cdefs[:cost]).value.should == "Import - 120.001\nImport - 12.00\nImport - 02.00\nImport - 01.00\nImport - 00.00"
  end

  it "should update existing style records and use missy style as master data" do
    @h.process make_row({:style => "P-ABC", :missy=>"M-ABC", :petite=>nil, :tall=>"T-ABC"}), @user
    p = Product.first
    p.unique_identifier.should == "M-ABC"
    p.get_custom_value(@cdefs[:related_styles]).value.split.sort.should == ['P-ABC','T-ABC']

  end

  it "should update maximum cost if the unit_price is higher and NOT update minimum cost" do
    @h.process make_row, @user

    unit_cost = (BigDecimal.new(default_values[:unit_cost]) + 1)
    row = make_row unit_cost: unit_cost.to_s
    @h.process row, @user

    p = Product.first
    p.classifications.first.get_custom_value(@cdefs[:maximum_cost]).value.should eq unit_cost
    p.classifications.first.get_custom_value(@cdefs[:minimum_cost]).value.should eq BigDecimal.new(default_values[:unit_cost])
  end

  it "should NOT update maximum cost if the unit_price is lower and update minimum cost" do
    @h.process make_row, @user

    unit_cost = (BigDecimal.new(default_values[:unit_cost]) - 1)
    row = make_row unit_cost: unit_cost.to_s
    @h.process row, @user

    p = Product.first
    p.classifications.first.get_custom_value(@cdefs[:maximum_cost]).value.should eq BigDecimal.new(default_values[:unit_cost])
    p.classifications.first.get_custom_value(@cdefs[:minimum_cost]).value.should eq unit_cost
  end

  it "should add a new classification to hold max/min cost for import locations" do
    @h.process make_row, @user

    other_country = Factory(:country, import_location: true, iso_code: 'XX')
    row = make_row import: "XX"
    @h.process row, @user

    p = Product.first
    c = p.classifications.find {|c| c.country_id == other_country.id}
    c.get_custom_value(@cdefs[:maximum_cost]).value.should eq BigDecimal.new(default_values[:unit_cost])
    c.get_custom_value(@cdefs[:minimum_cost]).value.should eq BigDecimal.new(default_values[:unit_cost])
  end

  it "should not add new classification to hold max/min cost for countries not marked as import locations" do
    @h.process make_row, @user

    other_country = Factory(:country, import_location: false, iso_code: 'XX')
    row = make_row import: "XX"
    @h.process row, @user

    Product.first.classifications.find {|c| c.country_id == other_country.id}.should be_nil    
  end

  describe "parse" do
    it "parses a file using integration user" do
      user = Factory(:user, username: 'integration')
      data = make_row
      described_class.parse data

      p = Product.first
      expect(p).not_to be_nil
      expect(p.unique_identifier).to eq '123456'
      expect(p.last_updated_by).to eq user
    end
  end
end
