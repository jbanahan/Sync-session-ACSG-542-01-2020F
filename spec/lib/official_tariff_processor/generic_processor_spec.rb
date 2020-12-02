describe OpenChain::OfficialTariffProcessor::GenericProcessor do

  describe "process" do
    let(:country) { country = create(:country, iso_code:"US", european_union:false) }

    it "creates SPI rate records from a tariff" do
      tar = OfficialTariff.create!(country:country, special_rate_key:"abc", special_rates:"10% (A,B)", hts_code:"X")
      expect(described_class.process tar).to eq [{:program_code=>"A", :amount=>BigDecimal.new(".1"), :text=>"10%"}, {:program_code=>"B", :amount=>BigDecimal.new(".1"), :text=>"10%"}]

      r = SpiRate.where(program_code:"A").first
      expect(r).to_not be_nil
      # The exact value involves some MD5 hexing, which isn't really relevant to this test.
      expect(r.special_rate_key).to_not be_nil
      expect(r.country_id).to eq country.id
      expect(r.rate).to eq BigDecimal.new(".1")
      expect(r.rate_text).to eq "10%"

      r2 = SpiRate.where(program_code:"B").first
      expect(r2).to_not be_nil
    end

    it "does nothing if the SPI rate record already exists for a tariff" do
      tar = OfficialTariff.create!(country:country, special_rate_key:"abc", special_rates:"10% (A)", hts_code:"X")
      SpiRate.create!(special_rate_key:tar.special_rate_key, country_id:country.id, program_code:"X", rate_text:"X")

      expect(described_class.process tar).to be_nil

      # Should still be there.
      expect(SpiRate.where(program_code:"X").first).to_not be_nil
    end

    it "does nothing if there's no SPI rate records to build" do
      tar = OfficialTariff.create!(country:country, special_rate_key:"abc", special_rates:"Free", hts_code:"X")

      expect(described_class.process tar).to be_nil
    end

    it "handles SPI exception when log provided" do
      log = InboundFile.new

      expect(described_class).to receive(:parse_spi).and_raise("Unexpected SPI: invalid code")

      tar = OfficialTariff.create!(country:country, special_rate_key:"abc", special_rates:"10% (A,B)", hts_code:"X")
      expect(described_class.process(tar, log)).to eq nil

      expect(log).to have_warning_message "Unexpected SPI: invalid code"
    end

    it "re-raises SPI exception when no log provided" do
      expect(described_class).to receive(:parse_spi).and_raise("Unexpected SPI: invalid code")

      tar = OfficialTariff.create!(country:country, special_rate_key:"abc", special_rates:"10% (A,B)", hts_code:"X")
      expect { described_class.process(tar) }.to raise_error("Unexpected SPI: invalid code")
    end
  end

  describe "parse_spi" do
    let(:parse_data) { {parser: /([^(]+)\s*\(([^)]+)\)/, spi_split: /,\s*/, spi_cleanup: [[/^(.) (.)$/, '\1\2'], [/.*/, :upcase]], exceptions: [/^\s*Free\s*$/, /^$/], skip_spi: [/[YZ]/], replaces:{/DUMB PREFIX:\s*\+\d+\s*/=>''}} }

    it "parses SPI string" do
      expect(described_class.parse_spi parse_data, "Free (A,Z,Y,b)").to eq [{:program_code=>"A", :amount=>0, :text=>"Free"}, {:program_code=>"B", :amount=>0, :text=>"Free"}]
      expect(described_class.parse_spi parse_data, "10.25% (C)").to eq [{:program_code=>"C", :amount=>BigDecimal.new(".1025"), :text=>"10.25%"}]
      expect(described_class.parse_spi parse_data, "DUMB PREFIX: +10 Free (A)").to eq [{:program_code=>"A", :amount=>0, :text=>"Free"}]
      expect(described_class.parse_spi parse_data, "DUMB PREFIX: +10").to be_nil
      expect(described_class.parse_spi parse_data, " Free ").to be_nil
      expect(described_class.parse_spi parse_data, "5% (A B)").to eq [{:program_code=>"AB", :amount=>BigDecimal.new(".05"), :text=>"5%"}]
    end

    it "handles invalid SPI" do
      expect { described_class.parse_spi parse_data, "bogus" }.to raise_error "Invalid spi found for 'bogus'."
      expect { described_class.parse_spi parse_data, "Free ( )" }.to raise_error "Invalid parse expression: Free ( ) - (Bad elements: [\"Free \", \" \"]).  Each matched SPI expression should return exactly 2 non-blank match values."
    end

    describe "US" do
      let(:country) { country = create(:country, iso_code:"US", european_union:false) }
      let(:parse_data) { described_class.parse_data_for country }

      # None of these should raise exceptions.
      it "handles assorted penalties" do
        expect(described_class.parse_spi parse_data, "CHINA PENALTY: +25 (EX) Free (A)").to eq [{:program_code=>"A", :amount=>0, :text=>"Free"}]
        expect(described_class.parse_spi parse_data, "CHINA PENALTY: +25 (EX)").to be_nil
        expect(described_class.parse_spi parse_data, "CHINA PENALTY:  +100 ").to be_nil
        expect(described_class.parse_spi parse_data, "Steel PENALTY: +25 Free (A)").to eq [{:program_code=>"A", :amount=>0, :text=>"Free"}]
        expect(described_class.parse_spi parse_data, "Steel PENALTY: +25").to be_nil
        expect(described_class.parse_spi parse_data, "Alum PENALTY: +10 10% (A)").to eq [{:program_code=>"A", :amount=>BigDecimal.new(".1"), :text=>"10%"}]
        expect(described_class.parse_spi parse_data, "Alum PENALTY: +10").to be_nil
        expect(described_class.parse_spi parse_data, "Civil Aircraft Pen: +25 ").to be_nil
        expect(described_class.parse_spi parse_data, "Civil Aircraft Pen:  +50 Free (A)").to eq [{:program_code=>"A", :amount=>0, :text=>"Free"}]
      end
    end
  end

  describe "parse_rate" do
    it "should convert numeric rate to decimal value" do
      expect(described_class.parse_rate "53.35%").to eq BigDecimal(".5335")
      expect(described_class.parse_rate "1,00.000%").to eq BigDecimal(1)
      expect(described_class.parse_rate "2.2%:").to eq BigDecimal(".022")
      expect(described_class.parse_rate "FREE").to eq 0
      expect(described_class.parse_rate "free").to eq 0
      expect(described_class.parse_rate "-53.35%").to be_nil
      expect(described_class.parse_rate "HA.HA%").to be_nil
      expect(described_class.parse_rate "99,999.99%").to be_nil
      expect(described_class.parse_rate "999.9999%").to be_nil
    end
  end

  describe "parse_data_for" do
    it "should return parse info for handled countries" do
      expect(described_class.parse_data_for create(:country, iso_code:"US", european_union:false)).to_not be_nil
      expect(described_class.parse_data_for create(:country, iso_code:"CA", european_union:false)).to_not be_nil
      expect(described_class.parse_data_for create(:country, iso_code:"FR", european_union:true)).to_not be_nil
      expect(described_class.parse_data_for create(:country, iso_code:"DE", european_union:true)).to_not be_nil
      expect(described_class.parse_data_for create(:country, iso_code:"CL", european_union:false)).to_not be_nil
      expect(described_class.parse_data_for create(:country, iso_code:"CN", european_union:false)).to_not be_nil
      expect(described_class.parse_data_for create(:country, iso_code:"MX", european_union:false)).to_not be_nil
      expect(described_class.parse_data_for create(:country, iso_code:"SG", european_union:false)).to_not be_nil
    end

    it "should rase an error for an unexpected country" do
      expect { described_class.parse_data_for create(:country, iso_code:"A+", european_union:false) }.to raise_error("No Special Program parser configured for A+")
    end
  end

end