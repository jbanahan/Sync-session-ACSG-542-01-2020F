require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UaTbdReportParser do
  before :each do
    @cf = double(:custom_file)
    att = double(:attached)
    att.stub(:path).and_return('mypath')
    @cf.stub(:attached).and_return(att)
    @cf.stub(:attached_file_name).and_return('attfilename')
  end
  describe :valid_style? do
    it "should not validate styles that are not [7 alphanumerics]-[3 alphanumerics]" do
      described_class.valid_style?('12345-12').should be_false
    end
    it "should not validate if it starts with a letter" do
      described_class.valid_style?('a123456-123').should be_false
    end
    it "should not validate if it starts with 9999999" do
      described_class.valid_style?('9999999-123').should be_false
    end
    it "should pass a valid style" do
      described_class.valid_style?('1a34567-1a3').should be_true
    end
  end
  describe :valid_plant? do
    it "should not validate a blank plant" do
      described_class.valid_plant?('').should be_false
    end
    it "should not validate plants 52, 61, 68" do
      ['0052','0061','0068'].each {|i| described_class.valid_plant?(i).should be_false}
    end
    it "should not validate a non-numeric 4 digit plant that doesn't start with I" do
      described_class.valid_plant?('a1').should be_false
    end
    it "should pass a valid plant" do
      described_class.valid_plant?('0011').should be_true
    end
    it "shoud pass I and 3 digits" do
      described_class.valid_plant?('I001').should be_true
    end
  end
  describe :prep_plant_code do
    it "should fix numeric" do
      described_class.prep_plant_code('17.0').should == '0017'
    end
  end
  describe :valid_material? do
    it "should not validate materials that contain DELETE" do
      described_class.valid_material?('this material is DELETED already').should be_false
    end
    it "should not validate materials that contain ERROR" do
      described_class.valid_material?('this material has an ERROR').should be_false
    end
    it "should pass anything else" do
      described_class.valid_material?('this material has no bad words').should be_true
    end
  end
  describe :valid_row? do
    before :each do
      @r = ['',
        '1234567-890',
        '99',
        'NotUsed',
        'NotUsed',
        'NotUsed',
        'NotUsed',
        'NotUsed',
        'NotUsed',
        'Material Desc',
        'NotUsed'
      ]
    end
    it "should fail with empty material" do
      @r[9] = ''
      described_class.valid_row?(@r).should be_false
    end
    it "should fail with empty plant" do
      @r[2] = ''
      described_class.valid_row?(@r).should be_false
    end
    it "should fail with empty style" do
      @r[1] = ''
      described_class.valid_row?(@r).should be_false
    end
    it "should fail if row is not 11 elements" do
      @r << 'x'
      described_class.valid_row?(@r).should be_false
    end
    it "should fail if row.first is not blank?" do
      @r[0] = 'x'
      described_class.valid_row?(@r).should be_false
    end
    it "should pass with valid_material?, valid_plant?, valid_style?" do
      described_class.valid_row?(@r).should be_true
    end
    it "should fail with !valid_material?, !valid_plant?, !valid_style?" do
      described_class.should_receive(:valid_material?).with(@r[9]).and_return false
      described_class.valid_row?(@r).should be_false
    end
  end
  describe :process do
    before :each do 
      @u = Factory(:user)
      @tmp = double('tmp')
      @tmp.stub(:path).and_return('mypath')
      OpenChain::S3.stub(:download_to_tempfile).and_return(@tmp)
      described_class.any_instance.stub(:can_view?).and_return true
    end
    it "should group styles and pass to parse_rows" do
      CSV.should_receive(:foreach).with(@tmp.path,{col_sep:"\t",encoding:"UTF-16LE:UTF-8",quote_char:"\0"})
        .and_yield(['','1234567-123','23','','','','','','','desc1',''])
        .and_yield(['','1234567-223','23','','','','','','','desc1',''])
        .and_yield(['','1234567-234','23','','','','','','','desc1',''])
        .and_yield(['','1234568-234','23','','','','','','','desc1',''])
        .and_yield(['','1234568-345','23','','','','','','','desc1',''])
        .and_yield(['','1234569-345','23','','','','','','','desc1',''])
      p = described_class.new(@cf)
      p.should_receive(:process_rows).with([
        ['','1234567-123','23','','','','','','','desc1',''],
        ['','1234567-223','23','','','','','','','desc1',''],
        ['','1234567-234','23','','','','','','','desc1','']
      ],@u)
      p.should_receive(:process_rows).with([
        ['','1234568-234','23','','','','','','','desc1',''],
        ['','1234568-345','23','','','','','','','desc1','']
      ],@u)
      p.should_receive(:process_rows).with([
        ['','1234569-345','23','','','','','','','desc1',''],
      ],@u)
      p.process @u 
    end
    it "should write user message" do
      p = described_class.new(@cf)
      CSV.should_receive(:foreach).with(@tmp.path,{col_sep:"\t",encoding:"UTF-16LE:UTF-8",quote_char:"\0"})
        .and_yield(['','1234567-123','23','','','','','','','desc1',''])
      p.process @u 
      msg = @u.messages.last
      msg.body.should include @cf.attached_file_name
    end
    it "should log message on failure" do
      p = described_class.new(@cf)
      CSV.should_receive(:foreach).and_raise("bad stuff")
      lambda {p.process @u}.should raise_error 'bad stuff'
      msg = @u.messages.last
      msg.body.should include @cf.attached_file_name
      msg.body.should include 'bad stuff' 
    end
  end
  describe :process_rows do
    before :each do
      @p = described_class.new(@cf)
      @u = Factory(:user)
    end
    it "should aggregate color and plant codes for new rows" do
      @p.process_rows [
        ['','1234567-123','23','','','','','','','desc1',''],
        ['','1234567-122','20','','','','','','','desc2','']
      ], @u
      #call prep_custom_definitions after process_rows so we make sure the base class
      #properly initializes the custom defintions without this call
      cdefs = described_class.prep_custom_definitions [:colors,:plant_codes]
      p = Product.find_by_unique_identifier('1234567')
      p.get_custom_value(cdefs[:colors]).value.should == "122\n123"
      p.get_custom_value(cdefs[:plant_codes]).value.should == "0020\n0023"
      p.name == "desc1" #use the first one
    end
    it "should not clear existing values when aggregating color and plant codes" do
      p = Factory(:product,unique_identifier:'1234567')
      cdefs = described_class.prep_custom_definitions [:colors,:plant_codes]
      p.update_custom_value! cdefs[:colors], '001'
      p.update_custom_value! cdefs[:plant_codes], '0066'
      @p.process_rows [
        ['','1234567-123','23','','','','','','','desc1',''],
        ['','1234567-122','20','','','','','','','desc2','']
      ], @u
      p = Product.find_by_unique_identifier('1234567')
      p.get_custom_value(cdefs[:colors]).value.should == "001\n122\n123"
      p.get_custom_value(cdefs[:plant_codes]).value.should == "0020\n0023\n0066"
    end
    it "should take entity snapshot" do
      @p.process_rows [
        ['','1234567-123','23','','','','','','','desc1',''],
        ['','1234567-122','20','','','','','','','desc2','']
      ], @u
      p = Product.find_by_unique_identifier('1234567')
      p.should have(1).entity_snapshots
      p.entity_snapshots.first.user.should == @u
    end
    it "should set import countries based on plant codes" do
      c = Factory(:country,iso_code:'US')
      DataCrossReference.add_xref! DataCrossReference::UA_PLANT_TO_ISO, '0023', 'US'
      DataCrossReference.add_xref! DataCrossReference::UA_PLANT_TO_ISO, '0020', 'CA'
      @p.process_rows [
        ['','1234567-123','23','','','','','','','desc1',''],
        ['','1234567-122','20','','','','','','','desc2','']
      ], @u
      imp_country_cd = described_class.prep_custom_definitions([:import_countries])[:import_countries]
      p = Product.find_by_unique_identifier('1234567')
      p.get_custom_value(imp_country_cd).value.should == "CA\nUS"
    end
  end
end
