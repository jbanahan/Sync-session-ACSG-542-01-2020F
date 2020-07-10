describe TariffLoader do

  let (:xls_path) { 'spec/support/bin/SAMPLE_SIMPLE_TARIFF_ENG.xls' }

  describe 'process' do
    it 'creates a tariff set object' do
      country = Factory(:country, iso_code:"AU")
      time = Time.zone.now.strftime("%Y-%m-%d")
      tl = TariffLoader.new(country, xls_path, time)

      expect(tl.process).to be_kind_of(TariffSet).and have_attributes(country: country, label: time)
    end
  end

  describe 'parse_spc_rates' do

    let(:china) {Factory(:country, iso_code:"CN")}
    let(:tariff_loader) { TariffLoader.new(china, xls_path, Time.zone.now.strftime("%Y-%m-%d")) }
    let(:official_tariff) { Factory(:official_tariff, country: china) }

    it 'sets the special_rates on a given official tariff and a value' do
      expect(official_tariff.special_rates).to be_nil
      tariff_loader.send(:parse_spc_rates, official_tariff, "5.000000%")
      expect(official_tariff.special_rates).to eq "5.000000%"
    end

    context "tariff country is in the MOST_FAVORED_NATION_SPECIAL_PARSE_ISOS constant array" do

      before {described_class.instance_variable_set(:@do_mfn_parse, true)}

      it 'sets the most_favored_nation_rate' do
        expect(official_tariff.most_favored_nation_rate).to be_nil
        tariff_loader.send(:parse_spc_rates, official_tariff, "0.00000000%: (LDC1,LDC2,LDC,CL,ASEAN: BN,ASEAN: KH,ASEAN: ID,ASEAN: LA,ASEAN: MY,ASEAN: MM,ASEAN: PH,ASEAN: SG,ASEAN: TH,ASEAN: VN,HK,MO,Special-KH,PK,SG,NZ,PE,CR,IS FTA,AU FTA,Georgia), 100.00000000%: (General), 3.00000000%: (CH FTA), 33.00000000%: (US Penalty), 4.00000000%: (KR FTA), 5.20000000%: (APTA-5), 8.00000000%: (MFN tariff treatment)")
        expect(official_tariff.most_favored_nation_rate).to eq "8.00000000%"
      end
    end

    context "tariff country is any other country" do

      before {described_class.instance_variable_set(:@do_mfn_parse, false)}

      it 'does not set the most_favored_nation_rate' do
        country = Factory(:country, iso_code:"AU")
        time = Time.zone.now.strftime("%Y-%m-%d")
        tl = TariffLoader.new(country, xls_path, time)

        tl.send(:parse_spc_rates, official_tariff, "0.00000000%: (LDC,LDC1,LDC2,CL,ASEAN: BN,ASEAN: KH,ASEAN: ID,ASEAN: LA,ASEAN: MY,ASEAN: MM,ASEAN: PH,ASEAN: SG,ASEAN: TH,ASEAN: VN,HK,MO,Special-KH,Special-LA,NZ,IS FTA), 12.00000000%: (KR FTA), 20.00000000%: (MFN tariff treatment), 45.00000000%: (US Penalty), 5.30000000%: (PE), 6.00000000%: (CH FTA), 6.70000000%: (CR), 70.00000000%: (General), 8.00000000%: (AU FTA,Georgia)")
        expect(official_tariff.most_favored_nation_rate).to be_nil
      end
    end
  end

  describe 'parse_file' do
    let (:log) { InboundFile.new }

    it 'processes a file' do
      country = Factory(:country, iso_code:"AU")

      now = Date.new(2017, 8, 9)

      loader = double("loader")
      expect(described_class).to receive(:new).with(country, "some_folder/au_simple_20170707.zip", "AU-2017-08-09").and_return loader
      tariff_set = double("tariff_set")
      expect(loader).to receive(:process).and_return(tariff_set)
      expect(tariff_set).to receive(:activate).with(nil, log)

      Timecop.freeze(now) do
        described_class.parse_file "some_folder/au_simple_20170707.zip", log
      end
    end

    it 'raises error on invalid country' do
      expect { described_class.parse_file "some_folder/au_simple_20170707.zip", log }.to raise_error(LoggedParserFatalError, "Country not found with ISO AU for file au_simple_20170707.zip")

      expect(log.get_messages_by_status(InboundFile::PROCESS_STATUS_ERROR)[0].message).to eq "Country not found with ISO AU for file au_simple_20170707.zip"
    end
  end

  describe 'process_from_s3' do
    it "downloads and processes a file from S3" do
      tempfile = instance_double(Tempfile)
      allow(tempfile).to receive(:path).and_return "/path/to/the_key.zip"

      expect(OpenChain::S3).to receive(:download_to_tempfile).with("the_bucket", "the_key.zip", {original_filename: "the_key.zip"}).and_yield tempfile
      expect(described_class).to receive(:handle_processing).with("the_bucket", "the_key.zip", { some_option:"yup" }).and_yield { "/path/to/the_key.zip" }

      described_class.process_from_s3 "the_bucket", "the_key.zip", { some_option:"yup" }
    end
  end

  describe 'process_from_file' do
    it "processes a file" do
      f = instance_double(File)
      allow(f).to receive(:is_a?).with(File).and_return true
      allow(f).to receive(:path).and_return "/path/to/orig_file.zip"

      expect(described_class).to receive(:handle_processing).with(nil, "/path/to/orig_file.zip", { some_option:"yup" }).and_yield { "/path/to/orig_file.zip" }

      described_class.process_from_file f, { some_option:"yup" }
    end

    it "processes a file path" do
      expect(described_class).to receive(:handle_processing).with(nil, "/path/to/orig_file.zip", { some_option:"yup" }).and_yield { "/path/to/orig_file.zip" }

      described_class.process_from_file "/path/to/orig_file.zip", { some_option:"yup" }
    end
  end

  describe 'process_s3' do

    let (:tempfile) {
      t = instance_double(Tempfile)
      allow(t).to receive(:path).and_return "/path/to/file.zip"
      t
    }

    it 'processes and activates a file from S3' do
      country = instance_double(Country)
      user = Factory(:user)

      loader = instance_double(TariffLoader)
      expect(described_class).to receive(:new).with(country, "/path/to/file.zip", "AU-2017-08-09").and_return loader
      tariff_set = instance_double(TariffSet)
      expect(loader).to receive(:process).and_return(tariff_set)
      expect(tariff_set).to receive(:activate)

      expect(OpenChain::S3).to receive(:download_to_tempfile).with("chain-io", "s3_filename.zip", {original_filename: "s3_filename.zip"}).and_yield tempfile

      described_class.process_s3 "s3_filename.zip", country, "AU-2017-08-09", true, user

      expect(user.messages.length).to eq 1
      expect(user.messages[0].subject).to eq "Tariff Set AU-2017-08-09 Loaded"
      expect(user.messages[0].body).to eq "Tariff Set AU-2017-08-09 has been loaded and has been activated."
    end

    it 'processes a file from S3 but does not activate' do
      country = instance_double(Country)
      user = Factory(:user)

      loader = instance_double(TariffLoader)
      expect(described_class).to receive(:new).with(country, "/path/to/file.zip", "AU-2017-08-09").and_return loader
      tariff_set = instance_double(TariffSet)
      expect(loader).to receive(:process).and_return(tariff_set)
      expect(tariff_set).to_not receive(:activate)

      expect(OpenChain::S3).to receive(:download_to_tempfile).with("chain-io", "s3_filename.zip", {original_filename: "s3_filename.zip"}).and_yield tempfile

      described_class.process_s3 "s3_filename.zip", country, "AU-2017-08-09", false, user
    end

    # Basically just ensuring the method doesn't blow up if it's not given a user.
    it 'processes a file from S3 with no user provided' do
      country = instance_double(Country)

      loader = instance_double(TariffLoader)
      expect(described_class).to receive(:new).with(country, "/path/to/file.zip", "AU-2017-08-09").and_return loader
      tariff_set = instance_double(TariffSet)
      expect(loader).to receive(:process).and_return(tariff_set)
      expect(tariff_set).to receive(:activate)

      expect(OpenChain::S3).to receive(:download_to_tempfile).with("chain-io", "s3_filename.zip", {original_filename: "s3_filename.zip"}).and_yield tempfile

      described_class.process_s3 "s3_filename.zip", country, "AU-2017-08-09", true
    end
  end

  describe "column_value" do
    it "returns stripped value if strip-capable" do
      val = double("val", strip: "X")
      expect(described_class.column_value(val)).to eq "X"
    end

    it "returns self if not strip-capable" do
      val = double("val")
      expect(described_class.column_value(val)).to eq val
    end
  end

  describe "valid_header_row?" do
    it "returns false if too short" do
      # Only 9 columns: 1 short of the required amount.
      expect(described_class.valid_header_row?(["HSCODE", "FULL_DESC", "SPC_RATES", "SR1", "UNITCODE", "UOM", "UOM1", "GENERAL", "GENERAL_RATE"])).to eq false
    end

    it "returns false if no expected columns are contained in the row" do
      expect(described_class.valid_header_row?(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"])).to eq false
    end

    it "returns true if acceptably long and containing expected columns" do
      expect(described_class.valid_header_row?(["HSCODE", "FULL_DESC", "SPC_RATES", "SR1", "UNITCODE", "UOM", "UOM1", "GENERAL", "GENERAL_RATE", "Not a real column but doesn't matter"])).to eq true
    end
  end

  describe "valid_row?" do
    it "returns false if too short" do
      # Only 9 columns: 1 short of the required amount.
      expect(described_class.valid_row?(["A", "B", "C", "D", "E", "F", "G", "H", "I"])).to eq false
    end

    it "returns false if all values are blank" do
      expect(described_class.valid_row?([nil, "", "", nil, "", "", "", "", nil, ""])).to eq false
    end

    it "returns true if acceptably long and at least one value provided" do
      expect(described_class.valid_row?([nil, "", "", nil, "Hey, there's one value in here", "", "", "", nil, ""])).to eq true
    end

    it "returns true if acceptably long and at least one numeric value provided" do
      expect(described_class.valid_row?([nil, "", "", nil, 42, "", "", "", "", nil, ""])).to eq true
    end
  end
end
