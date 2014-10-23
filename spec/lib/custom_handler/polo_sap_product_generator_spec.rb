# encoding: utf-8

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
  describe :run_schedulable do
    it "should call ftp_file & sync_csv" do
      pg = mock 'product generator'
      csv_output = mock 'CSV Output'
      pg.should_receive(:ftp_file).with(csv_output).and_return('x')
      pg.should_receive(:sync_csv).and_return(csv_output)
      described_class.should_receive(:new).with("ABC").and_return(pg)
      described_class.run_schedulable "ABC"
    end
  end

  it "should raise error if no sap brand custom definition" do
    @sap_brand_cd.destroy
    lambda {described_class.new}.should raise_error
  end
  describe :sync_csv do
    before :each do
      @us = Factory(:country,:iso_code=>'US')
    end
    it "should not send countries except US, CA, IT, KR, JP, HK with custom where" do
      ca = Factory(:country,:iso_code=>'CA')
      italy = Factory(:country,:iso_code=>'IT')
      nz = Factory(:country,:iso_code=>'NZ')
      p = Factory(:product)
      p.update_custom_value! @sap_brand_cd, true
      [@us,ca,italy,nz].each do |country|
        Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>country.id,:product=>p))
      end
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(3).items
      a.collect {|x| x[2]}.sort.should == ['CA','IT','US']
    end
    it "should allow custom list of valid countries" do
      italy = Factory(:country,:iso_code=>'IT')
      nz = Factory(:country,:iso_code=>'NZ')
      p = Factory(:product)
      p.update_custom_value! @sap_brand_cd, true
      [@us,italy,nz].each do |country|
        Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>country.id,:product=>p))
      end
      @tmp = described_class.new(:custom_where=>"WHERE 1=1",:custom_countries=>['NZ','IT']).sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(2).items
      a.collect {|x| x[2]}.sort.should == ['IT','NZ']
    end
    it "should not send records with blank tariff numbers" do
      p1 = Factory(:product)
      p2 = Factory(:product)
      [p1,p2].each {|p| p.update_custom_value! @sap_brand_cd, true}
      Factory(:tariff_record,:classification=>Factory(:classification,:country_id=>@us.id,:product=>p1))
      Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@us.id,:product=>p2))
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(1).item
      a[0][0].should == p2.unique_identifier
    end
    it "should not send products that aren't SAP Brand" do
      p1 = Factory(:product)
      p1.update_custom_value! @sap_brand_cd, true
      p2 = Factory(:product) #no custom value at all
      p3 = Factory(:product) #false custom value
      p3.update_custom_value! @sap_brand_cd, false
      [p1,p2,p3].each {|p| Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@us.id,:product=>p))}
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(1).item
      a[0][0].should == p1.unique_identifier
    end
    it "should not limit if :no_brand_restriction = true" do
      p1 = Factory(:product)
      p1.update_custom_value! @sap_brand_cd, true
      p2 = Factory(:product) #no custom value at all
      p3 = Factory(:product) #false custom value
      p3.update_custom_value! @sap_brand_cd, false
      [p1,p2,p3].each {|p| Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@us.id,:product=>p))}
      @tmp = described_class.new(:no_brand_restriction=>true,:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(3).item
      a.collect {|x| x[0]}.sort.should == [p1.unique_identifier,p2.unique_identifier,p3.unique_identifier].sort
    end

    it "should sync and skip product with invalid UTF-8 data" do
      p1 = Factory(:product)
      p2 = Factory(:product, :unique_identifier => "Ænema")
      [p1, p2].each do |p|
        p.update_custom_value! @sap_brand_cd, true
        Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@us.id,:product=>p))
      end
      
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(1).item
      a.collect {|x| x[0]}.should == [p1.unique_identifier]
    end

    it "removes newlines" do
      p = Factory(:product, :unique_identifier => "Test\r\nTest")
      p.update_custom_value! @sap_brand_cd, true
      Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@us.id,:product=>p))

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      a.should have(1).item
      a.collect {|x| x[0]}.should == ["Test  Test"]
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
      @vals[4] = "a\r\n\"b"
      r = @g.before_csv_write 1, @vals
      r[1].should == "a b"
      r[2].should == "a b"
      r[4].should == "a   b"
    end
  end

  describe :preprocess_row do
    it "should handle converting UTF-8 'EN-DASH' characters to hyphens" do
      # Note the "long hyphen" character...it's the unicode 2013 char
      r = @g.preprocess_row(0 => "This is a – test.")
      r.should eq [{0=>"This is a - test."}]
    end

    it "should handle converting UTF-8 'EM-DASH' characters to hyphens" do
      # Note the "long hyphen" character...it's the unicode 2014 char
      r = @g.preprocess_row(0 => "This is a — test.")
      r.should eq [{0=>"This is a - test."}]
    end

    it "should convert ¾ to 3/4" do
      r = @g.preprocess_row(0 => "This is a ¾ test.")
      r.should eq [{0=>"This is a 3/4 test."}]
    end

    it "should convert forbidden characters to spaces" do
      r = @g.preprocess_row(0 => "This\tis\ta\ttest.<>^&{}[]+|~*;?")
      r.should eq [{0 => "This is a test.              "}]
    end

    it "should handle non-string data" do
      v = {
        0 => BigDecimal.new(123),
        1 => 123, 
        2 => 123.4, 
        3 => Time.now, 
        4 => nil
      }

      r = @g.preprocess_row v
      r.should eq [v]
    end

    context :invalid_ascii_chars do 
      before :each do
        StandardError.any_instance.should_receive(:log_me) do |arg|
          @error_message = arg
        end
      end

      it "should log an error for non-printing chars" do
        # Just use any non-printing char
        r = @g.preprocess_row(0=>1, 2=>"\v")
        r.should be_nil

        @error_message.should eq ["Invalid character data found in product with unique_identifier '1'."]
      end

      it "should fail on delete char" do
        # Delete char is ASCII 127 and is not a printable character
        # Only reason it's in a test here is that there had to be special handling since it's ascii 127
        r = @g.preprocess_row(0=>1, 2 => "␡")
        r.should be_nil

        @error_message.should eq ["Invalid character data found in product with unique_identifier '1'."]
      end

      it "should log an error for non-ASCII chars" do
        r = @g.preprocess_row(0=>1, 2 =>"Æ")
        r.should be_nil

        @error_message.should eq ["Invalid character data found in product with unique_identifier '1'."]
      end

    end
  end

end
