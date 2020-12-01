describe OpenChain::CustomHandler::PoloSapProductGenerator do
  before :all do
    @cdefs = described_class.prep_custom_definitions described_class.cdefs
  end

  after :all do
    @cdefs.values.each(&:destroy)
  end

  before :each do
    @sap_brand_cd = FactoryBot(:custom_definition, :label=>'SAP Brand', :module_type=>'Product', :data_type=>'boolean')
  end

  after :each do
    @tmp.close! if @tmp
  end
  describe "sync_code" do
    it "should be polo_sap" do
      expect(subject.sync_code).to eq('polo_sap')
    end
  end
  describe "run_schedulable" do

    before :each do
      us = FactoryBot(:country, :iso_code=>'US')
      ca = FactoryBot(:country, :iso_code=>'CA')
      italy = FactoryBot(:country, :iso_code=>'IT')
      nz = FactoryBot(:country, :iso_code=>'NZ')
      @p = FactoryBot(:product)
      @p.update_custom_value! @sap_brand_cd, true
      @p2 = FactoryBot(:product)
      @p2.update_custom_value! @sap_brand_cd, true
      [us, ca, italy, nz].each do |country|
        FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>country.id, :product=>@p))
        FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>country.id, :product=>@p2))
      end
      @p.update_column :updated_at, (1.year.ago)
      @files = []
    end

    after :each do
      @files.each {|f| f.close! unless f.closed?}
    end

    it "should call ftp_file & sync_xml repeatedly until all products are sent" do
      expect_any_instance_of(described_class).to receive(:ftp_file).exactly(2).times do |instance, file|
        @files << file
      end
      # Mock out the max product count so we only have 1 product per file
      expect_any_instance_of(described_class).to receive(:max_products).exactly(3).times.and_return 1
      described_class.run_schedulable
      expect(@files.size).to eq 2

      expect(REXML::XPath.each(REXML::Document.new(@files[0].read).root, "product/style").map(&:text).uniq).to eq [@p.unique_identifier]
      expect(REXML::XPath.each(REXML::Document.new(@files[1].read).root, "product/style").map(&:text).uniq).to eq [@p2.unique_identifier]

      expect(@p.reload.sync_records.first.trading_partner).to eq "polo_sap"
      expect(@p2.reload.sync_records.first.trading_partner).to eq "polo_sap"
    end
  end

  it "should raise error if no sap brand custom definition" do
    @sap_brand_cd.destroy
    expect { subject }.to raise_error RuntimeError
  end

  describe "sync_xml" do

    before :each do
      @us = FactoryBot(:country, :iso_code=>'US')
    end

    it "it generates an xml file" do
      ca = FactoryBot(:country, :iso_code=>'CA')
      p = FactoryBot(:product)
      p.update_custom_value! @sap_brand_cd, true
      [@us, ca].each do |country|
        FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>country.id, :product=>p))
      end

      @cdefs.each do |key, cdef|
        value = nil

        if ["string", "text"].include? cdef.data_type.to_s
          if key == :country_of_origin
            # There's special handling that blanks COO's w/ a length > 2, we don't want to trip that here
            value = "CO"
          elsif key == :knit_woven
            value = "KNIT"
          else
            value = key.to_s
          end

        elsif "boolean" == cdef.data_type.to_s
          value = true
        end

        p.update_custom_value! @cdefs[key], value
      end

      p.update_custom_value! @cdefs[:clean_fiber_content], nil

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      root = doc.root

      ps = REXML::XPath.each(root, "product").map {|v| v}
      expect(ps.size).to eq 2

      prod = ps.first
      expect(prod.text("style")).to eq p.unique_identifier
      # Make sure the element is there, even if there's no actual text node
      expect(prod.text("long_description")).to be_nil
      expect(prod.elements["long_description"]).not_to be_nil
      expect(prod.text("fiber_content")).to eq "fiber_content"
      expect(prod.text("down_indicator")).to eq "Y"
      expect(prod.text("country_of_origin")).to eq "CO"
      expect(prod.text("hts")).to eq "1234.56.7890"
      expect(prod.text("cites")).to eq "Y"
      expect(prod.text("classification_country")).to eq "CA"
      expect(prod.text("fish_and_wildlife")).to eq "Y"
      expect(prod.text("genus_1")).to eq "common_name_1"
      expect(prod.text("species_1")).to eq "scientific_name_1"
      expect(prod.text("cites_origin_1")).to eq "fish_wildlife_origin_1"
      expect(prod.text("cites_source_1")).to eq "fish_wildlife_source_1"
      expect(prod.text("genus_2")).to eq "common_name_2"
      expect(prod.text("species_2")).to eq "scientific_name_2"
      expect(prod.text("cites_origin_2")).to eq "fish_wildlife_origin_2"
      expect(prod.text("cites_source_2")).to eq "fish_wildlife_source_2"
      expect(prod.text("genus_3")).to eq "common_name_3"
      expect(prod.text("species_3")).to eq "scientific_name_3"
      expect(prod.text("cites_origin_3")).to eq "fish_wildlife_origin_3"
      expect(prod.text("cites_source_3")).to eq "fish_wildlife_source_3"
      expect(prod.text("genus_4")).to eq "common_name_4"
      expect(prod.text("species_4")).to eq "scientific_name_4"
      expect(prod.text("cites_origin_4")).to eq "fish_wildlife_origin_4"
      expect(prod.text("cites_source_4")).to eq "fish_wildlife_source_4"
      expect(prod.text("genus_5")).to eq "common_name_5"
      expect(prod.text("species_5")).to eq "scientific_name_5"
      expect(prod.text("cites_origin_5")).to eq "fish_wildlife_origin_5"
      expect(prod.text("cites_source_5")).to eq "fish_wildlife_source_5"
      expect(prod.text("stitch_count_2cm_vertical")).to be_nil
      expect(prod.text("stitch_count_2cm_horizontal")).to be_nil
      expect(prod.text("allocation_category")).to eq "allocation_category"
      expect(prod.text("knit_woven")).to eq "KNT"

      # the only thing different about the second will be the classification country (which are ordered by iso code, so US must be second)
      prod = ps.second
      expect(prod.text("classification_country")).to eq "US"
    end

    it "maps 'woven' value to 'WVN'" do
      p = FactoryBot(:product)
      p.update_custom_value! @sap_brand_cd, true
      FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country=>@us, :product=>p))
      p.update_custom_value! @cdefs[:knit_woven], "Woven"
       @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      root = doc.root

      ps = REXML::XPath.each(root, "product").map {|v| v}
      expect(ps.size).to eq 1

      prod = ps.first
      expect(prod.text("knit_woven")).to eq "WVN"
    end

    it "should not send countries except US, CA, IT, KR, JP, HK, NO with custom where" do
      ca = FactoryBot(:country, :iso_code=>'CA')
      italy = FactoryBot(:country, :iso_code=>'IT')
      nz = FactoryBot(:country, :iso_code=>'NZ')
      no = FactoryBot(:country, :iso_code => "NO")
      jp = FactoryBot(:country, :iso_code => "JP")
      kr = FactoryBot(:country, :iso_code => "KR")
      hk = FactoryBot(:country, :iso_code => "HK")
      p = FactoryBot(:product)
      p.update_custom_value! @sap_brand_cd, true
      [@us, ca, italy, nz, no, jp, kr, hk].each do |country|
        FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>country.id, :product=>p))
      end

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product").size).to eq 7
      expect(REXML::XPath.each(doc.root, "product/classification_country").map(&:text).sort).to eq ["CA", "IT", "US", "NO", "JP", "KR", "HK"].sort
    end

    it "should allow custom list of valid countries" do
      italy = FactoryBot(:country, :iso_code=>'IT')
      nz = FactoryBot(:country, :iso_code=>'NZ')
      p = FactoryBot(:product)
      p.update_custom_value! @sap_brand_cd, true
      [@us, italy, nz].each do |country|
        FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>country.id, :product=>p))
      end
      @tmp = described_class.new(:custom_where=>"WHERE 1=1", :custom_countries=>['NZ', 'IT']).sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product/classification_country").map(&:text)).to eq ['IT', 'NZ']
    end

    it "should not send records with blank tariff numbers" do
      p1 = FactoryBot(:product)
      p2 = FactoryBot(:product)
      [p1, p2].each {|p| p.update_custom_value! @sap_brand_cd, true}
      FactoryBot(:tariff_record, :classification=>FactoryBot(:classification, :country_id=>@us.id, :product=>p1))
      FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>@us.id, :product=>p2))

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product/style").map(&:text)).to eq [p2.unique_identifier]
    end

    it "sends clean_fiber_content if clean_fiber_content is set" do
      p = FactoryBot(:product)
      FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>@us.id, :product=>p))

      p.update_custom_value! @cdefs[:clean_fiber_content], "cleanfibercontent"
      p.update_custom_value! @sap_brand_cd, true

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product/fiber_content").map(&:text)).to eq ["cleanfibercontent"]
    end

    it "should not send products that aren't SAP Brand" do
      p1 = FactoryBot(:product)
      p1.update_custom_value! @sap_brand_cd, true
      p2 = FactoryBot(:product) # no custom value at all
      p3 = FactoryBot(:product) # false custom value
      p3.update_custom_value! @sap_brand_cd, false
      [p1, p2, p3].each {|p| FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>@us.id, :product=>p))}

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product/style").map(&:text)).to eq [p1.unique_identifier]
    end

    it "should not limit if :no_brand_restriction = true" do
      p1 = FactoryBot(:product)
      p1.update_custom_value! @sap_brand_cd, true
      p2 = FactoryBot(:product) # no custom value at all
      p3 = FactoryBot(:product) # false custom value
      p3.update_custom_value! @sap_brand_cd, false
      [p1, p2, p3].each {|p| FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>@us.id, :product=>p))}

      @tmp = described_class.new(:no_brand_restriction=>true, :custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product/style").map(&:text).sort).to eq [p1.unique_identifier, p2.unique_identifier, p3.unique_identifier].sort
    end

    it "should sync and skip product with invalid UTF-8 data" do
      p1 = FactoryBot(:product)
      p2 = FactoryBot(:product, :unique_identifier => "Ænema")
      [p1, p2].each do |p|
        p.update_custom_value! @sap_brand_cd, true
        FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>@us.id, :product=>p))
      end
      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product/style").map(&:text)).to eq [p1.unique_identifier]
    end

    it "removes newlines" do
      p = FactoryBot(:product, :unique_identifier => "Test\r\nTest")
      p.update_custom_value! @sap_brand_cd, true
      FactoryBot(:tariff_record, :hts_1=>'1234567890', :classification=>FactoryBot(:classification, :country_id=>@us.id, :product=>p))

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product/style").map(&:text)).to eq ["Test  Test"]
    end

    it "does not send multiple classifications for the same style/country combo" do
      eu = FactoryBot(:country, :iso_code=>'IT')
      # Create multiple products to ensure the checks against the previous style/iso are done correctly
      p = FactoryBot(:product, unique_identifier: "ZZZ")
      p.update_custom_value! @sap_brand_cd, true
      # Set the line numbers different from the natural id order to ensure we're sorting on line number
      FactoryBot(:tariff_record, :hts_1=>'1234567890', line_number: "2", classification: FactoryBot(:classification, :country_id=>@us.id, :product=>p))
      FactoryBot(:tariff_record, :hts_1=>'9876543210', line_number: "1", classification: p.classifications.first)
      # Create an IT classification to ensure we're ording correctly on country iso and that we're taking the country code into account when
      # checking for multiple tariff lines
      FactoryBot(:tariff_record, :hts_1=>'1234567890', line_number: "1", classification: FactoryBot(:classification, :country_id=>eu.id, :product=>p))

      p2 = nil
      Timecop.freeze(Time.zone.now - 7.days) do
        p2 = FactoryBot(:product, unique_identifier: "AAA")
        p2.update_custom_value! @sap_brand_cd, true
        FactoryBot(:tariff_record, :hts_1=>'1234567890', line_number: "2", classification: FactoryBot(:classification, :country_id=>@us.id, :product=>p2))
      end

      @tmp = described_class.new(:custom_where=>"WHERE 1=1").sync_xml
      doc = REXML::Document.new(IO.read(@tmp.path))
      expect(REXML::XPath.each(doc.root, "product").size).to eq 3
      expect(REXML::XPath.each(doc.root, "product/style").map(&:text)).to eq ["AAA", "ZZZ", "ZZZ"]
      expect(REXML::XPath.each(doc.root, "product/classification_country").map(&:text)).to eq ["US", "IT", "US"]
      expect(REXML::XPath.each(doc.root, "product/hts").map(&:text)).to eq ["1234.56.7890", "1234.56.7890", "9876.54.3210"]
    end
  end

  describe "ftp_credentials" do
    it "should send proper credentials" do
      expect(subject.ftp_credentials).to eq subject.connect_vfitrack_net('to_ecs/ralph_lauren/sap_prod')
    end
    it "should set qa folder if :env=>:qa in class initializer" do
      expect(described_class.new(env: :qa).ftp_credentials).to eq subject.connect_vfitrack_net('to_ecs/ralph_lauren/sap_qa')
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
      r = subject.before_csv_write 1, @vals
      @vals[3] = '1234.56.7890'
      expect(r).to eq(@vals)
    end
    it "should capitalize country of origin" do
      @vals[8] = 'us'
      r = subject.before_csv_write 1, @vals
      expect(r[8]).to eq("US")
    end
    it "should not send country of origin unless it is 2 digits" do
      @vals[8] = "ABC"
      r = subject.before_csv_write 1, @vals
      expect(r[8]).to eq("")
    end
    it "should clean line breaks and new lines" do
      @vals[1] = "a\nb"
      @vals[2] = "a\rb"
      @vals[4] = "a\r\n\"b"
      r = subject.before_csv_write 1, @vals
      expect(r[1]).to eq("a b")
      expect(r[2]).to eq("a b")
      expect(r[4]).to eq("a   b")
    end
  end

  describe "preprocess_row" do
    it "should handle converting UTF-8 'EN-DASH' characters to hyphens" do
      # Note the "long hyphen" character...it's the unicode 2013 char
      r = subject.preprocess_row(0 => "This is a – test.")
      expect(r).to eq [{0=>"This is a - test."}]
    end

    it "should handle converting UTF-8 'EM-DASH' characters to hyphens" do
      # Note the "long hyphen" character...it's the unicode 2014 char
      r = subject.preprocess_row(0 => "This is a — test.")
      expect(r).to eq [{0=>"This is a - test."}]
    end

    it "should convert ¾ to 3/4" do
      r = subject.preprocess_row(0 => "This is a ¾ test.")
      expect(r).to eq [{0=>"This is a 3/4 test."}]
    end

    it "should convert ® to blank" do
      expect(subject.preprocess_row(0 => "This is a ® test.")[0][0]).to eq "This is a  test."
    end

    it "should convert forbidden characters to spaces" do
      r = subject.preprocess_row(0 => "This\tis\ta\ttest.<>^&{}[]+|~*;?")
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

      r = subject.preprocess_row v
      expect(r).to eq [v]
    end

    context "invalid_ascii_chars" do
      it "should log an error for non-printing chars" do
        # Just use any non-printing char
        r = subject.preprocess_row(0=>1, 2=>"\v")
        expect(r).to be_nil

        expect(ErrorLogEntry.last.additional_messages).to eq ["Invalid character data found in product with unique_identifier '1'."]
      end

      it "should fail on delete char" do
        # Delete char is ASCII 127 and is not a printable character
        # Only reason it's in a test here is that there had to be special handling since it's ascii 127
        r = subject.preprocess_row(0=>1, 2 => "␡")
        expect(r).to be_nil

        expect(ErrorLogEntry.last.additional_messages).to eq ["Invalid character data found in product with unique_identifier '1'."]
      end

      it "should log an error for non-ASCII chars" do
        r = subject.preprocess_row(0=>1, 2 =>"Æ")
        expect(r).to be_nil

        expect(ErrorLogEntry.last.additional_messages).to eq ["Invalid character data found in product with unique_identifier '1'."]
      end

    end
  end

end
