describe OpenChain::CustomHandler::Vandegrift::ActiveRecordKewillProductGeneratorSupport do
  subject do
    Class.new do
      include OpenChain::CustomHandler::Vandegrift::ActiveRecordKewillProductGeneratorSupport

      def build_data(product)
        d = self.class::ProductData.new
        d.part_number = product.unique_identifier

        d
      end

      def ftp_credentials
        {folder: "credentials"}
      end
    end.new
  end

  describe "find_products" do
    let(:us) { Factory(:country, iso_code: "US") }
    let(:importer) { Factory(:importer) }
    let!(:product) do
      p = Factory(:product, unique_identifier: "12345-67", importer: importer)
      c = p.classifications.create!(country: us)
      c.tariff_records.create!(line_number: 1, hts_1: "9903123456")

      p
    end

    it "finds products available to be sycned" do
      expect(subject.find_products([importer], "CMUS", 1).to_a).to eq [product]
    end

    it "does not find inactive products" do
      product.update! inactive: true
      expect(subject.find_products([importer], "CMUS", 1).to_a).to eq []
    end

    it "does not find products without classifications" do
      product.classifications.destroy_all
      expect(subject.find_products([importer], "CMUS", 1).to_a).to eq []
    end

    it "does not find products without us classifications" do
      product.classifications.first.update! country: Factory(:country)
      expect(subject.find_products([importer], "CMUS", 1).to_a).to eq []
    end

    it "does not find products with tariff numbers less than 8 chars" do
      product.classifications.first.tariff_records.first.update! hts_1: "1234567"
      expect(subject.find_products([importer], "CMUS", 1).to_a).to eq []
    end

    it "does not find products that have already been synced" do
      product.sync_records.create! trading_partner: "CMUS", sent_at: (Time.zone.now + 1.hour), confirmed_at: (Time.zone.now + 2.hours)
      expect(subject.find_products([importer], "CMUS", 1).to_a).to eq []
    end

    it "finds products that have been updated since a previous sync" do
      product.sync_records.create! trading_partner: "CMUS", sent_at: (Time.zone.now - 2.hours), confirmed_at: (Time.zone.now - 1.hour)
      expect(subject.find_products([importer], "CMUS", 1).to_a).to eq [product]
    end
  end

  describe "make_xml_file" do
    let(:product) { Factory(:product, unique_identifier: "12345") }

    it "builds xml file" do
      expect(subject).to receive(:preload_product).with(product)
      # This method is defined in that base support class
      expect(subject).to receive(:write_tariff_data_to_xml) do |_element, data|
        expect(data.part_number).to eq "12345"
      end

      now = Time.zone.parse("2020-04-20 12:00")
      Timecop.freeze(now) do
        subject.make_xml_file([product], "Trading Partner") do |xml, sync_records|
          expect(sync_records.length).to eq 1
          sr = sync_records.first
          expect(sr.trading_partner).to eq "Trading Partner"

          # Just make sure the xml's root element is as expected
          expect(REXML::Document.new(xml.read).root.name).to eq "requests"
        end
      end
    end
  end

  describe "set_sync_record" do
    let(:product) { Product.new }
    let(:now) { Time.zone.parse("2020-04-20 12:00") }

    it "sets creates a sync record if one doesn't already exist" do
      Timecop.freeze(now) do
        sr = subject.set_sync_record product, 'Test'
        expect(sr.trading_partner).to eq "Test"
        expect(sr.sent_at).to eq now
        expect(sr.confirmed_at).to eq(now + 1.minute)
        expect(sr.syncable).to eq product
      end
    end

    it "updates already existing sync records" do
      product.update! unique_identifier: "Product"
      sr = product.sync_records.create! trading_partner: "Test"

      sr1 = nil
      Timecop.freeze(now) do
        sr1 = subject.set_sync_record product, 'Test'
      end

      # The reason this is a little funky is because we're looking up the sync record in this method
      # from the database, and then not saving it yet (that comes later in the process)
      # So just make sure the record is the same record we created above (.ie id == id)
      # Then check that the expected values were set.
      expect(sr1).to eq sr

      expect(sr1.sent_at).to eq now
      expect(sr1.confirmed_at).to eq(now + 1.minute)
      expect(sr1.syncable).to eq product
    end
  end

  describe "generate_and_send_products" do
    let (:products) { [Product.new] }
    let (:sync_records) { [SyncRecord.new] }
    let (:ftp_file) { instance_double(File) }

    it "makes xml file, ftps it and saves sync records" do
      expect(subject).to receive(:make_xml_file).with(products, "CMUS").and_yield ftp_file, sync_records
      expect(subject).to receive(:ftp_sync_file).with(ftp_file, sync_records, subject.ftp_credentials)
      expect(sync_records).to all(receive(:save!))
      expect(subject.generate_and_send_products(products, "CMUS")).to eq 1
    end

    it "returns 0 if no products are found" do
      expect(subject).not_to receive(:make_xml_file)
      expect(subject.generate_and_send_products([], "CMUS")).to eq 0
    end
  end

  describe "sync_xml" do
    let (:products) { [Product.new] }
    let (:importer) { Company.new }

    it "finds products, generates xml and sends products" do
      expect(subject).to receive(:find_products).with(importer, "CMUS", 500).and_return products
      expect(subject).to receive(:generate_and_send_products).with(products, "CMUS").and_return 1

      subject.sync_xml importer
    end

    it "iterates on finding / sending if number of products found are equal to max output file size" do
      expect(subject).to receive(:find_products).with(importer, "CMUS", 1).and_return(products, [])
      expect(subject).to receive(:generate_and_send_products).with(products, "CMUS").and_return 1
      expect(subject).to receive(:generate_and_send_products).with([], "CMUS").and_return 0

      subject.sync_xml importer, max_products_per_file: 1
    end
  end
end
