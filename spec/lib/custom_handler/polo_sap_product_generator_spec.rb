require 'spec_helper'

describe OpenChain::CustomHandler::PoloSapProductGenerator do
  before :each do
    @sap_brand_cd = Factory(:custom_definition,:label=>'SAP Brand',:module_type=>'Product',:data_type=>'boolean')
    @g = described_class.new
  end

  after :each do
    @tmp.unlink if @tmp
  end
  describe :sync_code do
    it "should be polo_sap" do
      @g.sync_code.should == 'polo_sap'
    end
  end

  it "should raise error if no sap brand custom definition" do
    @sap_brand_cd.destroy
    lambda {described_class.new}.should raise_error
  end
  describe :sync_csv do
    it "should not send countries except US, CA, IT with custom where" do
      us = Factory(:country,:iso_code=>'US')
      ca = Factory(:country,:iso_code=>'CA')
      italy = Factory(:country,:iso_code=>'IT')
      kr = Factory(:country,:iso_code=>'KR')
      p = Factory(:product)
      p.update_custom_value! @sap_brand_cd, true
      [us,ca,italy,kr].each do |country|
        Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>country.id,:product=>p))
      end
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(3).items
      a.collect {|x| x[2]}.sort.should == ['CA','IT','US']
    end
    it "should not send products that aren't SAP Brand" do
      us = Factory(:country,:iso_code=>'US')
      p1 = Factory(:product)
      p1.update_custom_value! @sap_brand_cd, true
      p2 = Factory(:product) #no custom value at all
      p3 = Factory(:product) #false custom value
      p3.update_custom_value! @sap_brand_cd, false
      [p1,p2,p3].each {|p| Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>us.id,:product=>p))}
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(1).item
      a[0][0].should == p1.unique_identifier
    end
    it "should not limit if :no_brand_restriction = true" do
      us = Factory(:country,:iso_code=>'US')
      p1 = Factory(:product)
      p1.update_custom_value! @sap_brand_cd, true
      p2 = Factory(:product) #no custom value at all
      p3 = Factory(:product) #false custom value
      p3.update_custom_value! @sap_brand_cd, false
      [p1,p2,p3].each {|p| Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>us.id,:product=>p))}
      @tmp = described_class.new(:no_brand_restriction=>true,:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(3).item
      a.collect {|x| x[0]}.should == [p1.unique_identifier,p2.unique_identifier,p3.unique_identifier]
    end
  end

  describe :ftp_credentials do
    it "should send proper credentials" do
      @g.ftp_credentials.should == {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ralph_Lauren/sap_prod'}
    end
    it "should set qa folder if :env=>:qa in class initializer" do
      described_class.new(:env=>:qa).ftp_credentials.should == {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ralph_Lauren/sap_qa'}
    end
  end

  describe :before_csv_write do
    before :each do 
      @vals = []
      30.times {|i| @vals << i}
      @vals[3] = "1234567890"
      @vals[8] = "CA"
    end
    it "should hts_format HTS value if set type indicator is not X" do
      r = @g.before_csv_write 1, @vals
      @vals[3] = '1234.56.7890'
      r.should == @vals
    end
    it "should clear HTS if set type indicator is X" do
      @vals[9] = 'X'
      r = @g.before_csv_write 1, @vals
      @vals[3] = ''
      r.should == @vals
    end
    it "should capitalize country of origin" do
      @vals[8] = 'us'
      r = @g.before_csv_write 1, @vals
      r[8].should == "US"
    end
    it "should not send country of origin unless it is 2 digits" do
      @vals[8] = "ABC"
      r = @g.before_csv_write 1, @vals
      r[8].should == ""
    end
    it "should clean line breaks and new lines" do
      @vals[1] = "a\nb"
      @vals[2] = "a\rb"
      @vals[4] = "a\r\nb"
      r = @g.before_csv_write 1, @vals
      r[1].should == "a b"
      r[2].should == "a b"
      r[4].should == "a  b"
    end
  end


end
