require 'spec_helper'

describe OpenChain::CustomHandler::PoloSapProductGenerator do
  before :each do
    @sap_brand_cd = Factory(:custom_definition,:label=>'SAP Brand',:module_type=>'Product',:data_type=>'boolean')
    @g = described_class.new
  end

  after :each do
    @tmp.unlink if @tmp
  end
  describe "sync_code" do
    it "should be polo_sap" do
      expect(@g.sync_code).to eq('polo_sap')
    end
  end
  describe "run_schedulable" do

    before :each do
      us = Factory(:country,:iso_code=>'US')
      ca = Factory(:country,:iso_code=>'CA')
      italy = Factory(:country,:iso_code=>'IT')
      nz = Factory(:country,:iso_code=>'NZ')
      @p = Factory(:product)
      @p.update_custom_value! @sap_brand_cd, true
      @p2 = Factory(:product)
      @p2.update_custom_value! @sap_brand_cd, true
      [us,ca,italy,nz].each do |country|
        Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>country.id,:product=>@p))
        Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>country.id,:product=>@p2))
      end
      @p.update_column :updated_at, (1.year.ago)
      @files = []
    end

    after :each do
      @files.each {|f| f.close! unless f.closed?}
    end

    it "should call ftp_file & sync_csv repeatedly until all products are sent" do
      expect_any_instance_of(described_class).to receive(:ftp_file).exactly(2).times do |instance, file|
        @files << file
      end
      # Mock out the max product count so we only have 1 product per file
      expect_any_instance_of(described_class).to receive(:max_products).exactly(3).times.and_return 1
      described_class.run_schedulable
      expect(@files.size).to eq 2

      expect(IO.readlines(@files[0].path)[1].split(",")[0]).to eq @p.unique_identifier
      expect(IO.readlines(@files[1].path)[1].split(",")[0]).to eq @p2.unique_identifier

      expect(@p.reload.sync_records.first.trading_partner).to eq "polo_sap"
      expect(@p2.reload.sync_records.first.trading_partner).to eq "polo_sap"
    end
  end

  it "should raise error if no sap brand custom definition" do
    @sap_brand_cd.destroy
    expect {described_class.new}.to raise_error
  end
  describe "sync_csv" do
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
      expect(a.size).to eq(3)
      expect(a.collect {|x| x[2]}.sort).to eq(['CA','IT','US'])
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
      expect(a.size).to eq(2)
      expect(a.collect {|x| x[2]}.sort).to eq(['IT','NZ'])
    end
    it "should not send records with blank tariff numbers" do
      p1 = Factory(:product)
      p2 = Factory(:product)
      [p1,p2].each {|p| p.update_custom_value! @sap_brand_cd, true}
      Factory(:tariff_record,:classification=>Factory(:classification,:country_id=>@us.id,:product=>p1))
      Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@us.id,:product=>p2))
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      expect(a.size).to eq(1)
      expect(a[0][0]).to eq(p2.unique_identifier)
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
      expect(a.size).to eq(1)
      expect(a[0][0]).to eq(p1.unique_identifier)
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
      expect(a.size).to eq(3)
      expect(a.collect {|x| x[0]}.sort).to eq([p1.unique_identifier,p2.unique_identifier,p3.unique_identifier].sort)
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
      expect(a.size).to eq(1)
      expect(a.collect {|x| x[0]}).to eq([p1.unique_identifier])
    end

    it "removes newlines" do
      p = Factory(:product, :unique_identifier => "Test\r\nTest")
      p.update_custom_value! @sap_brand_cd, true
      Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country_id=>@us.id,:product=>p))

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      expect(a.size).to eq(1)
      expect(a.collect {|x| x[0]}).to eq(["Test  Test"])
    end

    it "does not send multiple classifications for the same style/country combo" do
      eu = Factory(:country,:iso_code=>'IT')
      # Create multiple products to ensure the checks against the previous style/iso are done correctly
      p = Factory(:product, unique_identifier: "ZZZ")
      p.update_custom_value! @sap_brand_cd, true
      # Set the line numbers different from the natural id order to ensure we're sorting on line number
      Factory(:tariff_record,:hts_1=>'1234567890', line_number: "2", classification: Factory(:classification,:country_id=>@us.id,:product=>p))
      Factory(:tariff_record,:hts_1=>'9876543210', line_number: "1", classification: p.classifications.first)
      # Create an IT classification to ensure we're ording correctly on country iso and that we're taking the country code into account when
      # checking for multiple tariff lines
      Factory(:tariff_record,:hts_1=>'1234567890', line_number: "1", classification: Factory(:classification,:country_id=>eu.id,:product=>p))

      # Make sure AAA is always sorted first
      p2 = nil
      Timecop.freeze(Time.zone.now - 7.days) do 
        p2 = Factory(:product, unique_identifier: "AAA")
        p2.update_custom_value! @sap_brand_cd, true
        Factory(:tariff_record,:hts_1=>'1234567890', line_number: "2", classification: Factory(:classification,:country_id=>@us.id,:product=>p2))
      end
      
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_csv
      a = CSV.parse(IO.read(@tmp.path),:headers=>true)
      expect(a.length).to eq 3

      expect(a[0][0]).to eq "AAA"

      expect(a[1][0]).to eq "ZZZ"
      expect(a[1][2]).to eq "IT"
      expect(a[1][3]).to eq "1234.56.7890"

      expect(a[2][0]).to eq "ZZZ"
      expect(a[2][2]).to eq "US"
      expect(a[2][3]).to eq "9876.54.3210"
    end
  end

  describe "ftp_credentials" do
    it "should send proper credentials" do
      expect(@g.ftp_credentials).to eq({:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ralph_Lauren/sap_prod'})
    end
    it "should set qa folder if :env=>:qa in class initializer" do
      expect(described_class.new(:env=>:qa).ftp_credentials).to eq({:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ralph_Lauren/sap_qa'})
    end
  end

  describe "before_csv_write" do
    before :each do 
      @vals = []
      30.times {|i| @vals << i}
      @vals[3] = "1234567890"
      @vals[8] = "CA"
    end
    it "should hts_format HTS value if set type indicator is not X" do
      r = @g.before_csv_write 1, @vals
      @vals[3] = '1234.56.7890'
      expect(r).to eq(@vals)
    end
    it "should capitalize country of origin" do
      @vals[8] = 'us'
      r = @g.before_csv_write 1, @vals
      expect(r[8]).to eq("US")
    end
    it "should not send country of origin unless it is 2 digits" do
      @vals[8] = "ABC"
      r = @g.before_csv_write 1, @vals
      expect(r[8]).to eq("")
    end
    it "should clean line breaks and new lines" do
      @vals[1] = "a\nb"
      @vals[2] = "a\rb"
      @vals[4] = "a\r\n\"b"
      r = @g.before_csv_write 1, @vals
      expect(r[1]).to eq("a b")
      expect(r[2]).to eq("a b")
      expect(r[4]).to eq("a   b")
    end
  end

  describe "preprocess_row" do
    it "should handle converting UTF-8 'EN-DASH' characters to hyphens" do
      # Note the "long hyphen" character...it's the unicode 2013 char
      r = @g.preprocess_row(0 => "This is a – test.")
      expect(r).to eq [{0=>"This is a - test."}]
    end

    it "should handle converting UTF-8 'EM-DASH' characters to hyphens" do
      # Note the "long hyphen" character...it's the unicode 2014 char
      r = @g.preprocess_row(0 => "This is a — test.")
      expect(r).to eq [{0=>"This is a - test."}]
    end

    it "should convert ¾ to 3/4" do
      r = @g.preprocess_row(0 => "This is a ¾ test.")
      expect(r).to eq [{0=>"This is a 3/4 test."}]
    end

    it "should convert ® to blank" do
      expect(@g.preprocess_row(0 => "This is a ® test.")[0][0]).to eq "This is a  test."
    end

    it "should convert forbidden characters to spaces" do
      r = @g.preprocess_row(0 => "This\tis\ta\ttest.<>^&{}[]+|~*;?")
      expect(r).to eq [{0 => "This is a test.              "}]
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
      expect(r).to eq [v]
    end

    context "invalid_ascii_chars" do 
      before :each do
        expect_any_instance_of(StandardError).to receive(:log_me) do |instance, arg|
          @error_message = arg
        end
      end

      it "should log an error for non-printing chars" do
        # Just use any non-printing char
        r = @g.preprocess_row(0=>1, 2=>"\v")
        expect(r).to be_nil

        expect(@error_message).to eq ["Invalid character data found in product with unique_identifier '1'."]
      end

      it "should fail on delete char" do
        # Delete char is ASCII 127 and is not a printable character
        # Only reason it's in a test here is that there had to be special handling since it's ascii 127
        r = @g.preprocess_row(0=>1, 2 => "␡")
        expect(r).to be_nil

        expect(@error_message).to eq ["Invalid character data found in product with unique_identifier '1'."]
      end

      it "should log an error for non-ASCII chars" do
        r = @g.preprocess_row(0=>1, 2 =>"Æ")
        expect(r).to be_nil

        expect(@error_message).to eq ["Invalid character data found in product with unique_identifier '1'."]
      end

    end
  end

end
