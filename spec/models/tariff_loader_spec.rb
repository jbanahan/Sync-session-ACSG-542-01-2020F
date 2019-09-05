describe TariffLoader do

  describe 'parse_file' do
    let (:log) { InboundFile.new }

    it 'processes a file' do
      country = Factory(:country, iso_code:"AU")

      now = Date.new(2017,8,9)

      loader = double("loader")
      expect(described_class).to receive(:new).with(country, "some_folder/au_simple_20170707.zip", "AU-2017-08-09").and_return loader
      tariff_set = double("tariff_set")
      expect(loader).to receive(:process).and_return(tariff_set)
      expect(tariff_set).to receive(:activate)

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
      expect(described_class.valid_header_row?(["HSCODE","FULL_DESC","SPC_RATES","SR1","UNITCODE","UOM","UOM1","GENERAL","GENERAL_RATE"])).to eq false
    end

    it "returns false if no expected columns are contained in the row" do
      expect(described_class.valid_header_row?(["A","B","C","D","E","F","G","H","I","J"])).to eq false
    end

    it "returns true if acceptably long and containing expected columns" do
      expect(described_class.valid_header_row?(["HSCODE","FULL_DESC","SPC_RATES","SR1","UNITCODE","UOM","UOM1","GENERAL","GENERAL_RATE", "Not a real column but doesn't matter"])).to eq true
    end
  end

  describe "valid_row?" do
    it "returns false if too short" do
      # Only 9 columns: 1 short of the required amount.
      expect(described_class.valid_row?(["A","B","C","D","E","F","G","H","I"])).to eq false
    end

    it "returns false if all values are blank" do
      expect(described_class.valid_row?([nil,"","",nil,"","","","",nil,""])).to eq false
    end

    it "returns true if acceptably long and at least one value provided" do
      expect(described_class.valid_row?([nil,"","",nil,"Hey, there's one value in here","","","",nil,""])).to eq true
    end

    it "returns true if acceptably long and at least one numeric value provided" do
      expect(described_class.valid_row?([nil,"","",nil,42,"","","","",nil,""])).to eq true
    end
  end

  # TODO process method is currently untested

end