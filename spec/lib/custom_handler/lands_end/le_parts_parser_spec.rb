describe OpenChain::CustomHandler::LandsEnd::LePartsParser do

  let (:row) {
    ['style', 'suf ind', 'exc code', 'suf', 'FactoryBot', "FactoryBot Name", "Addr 1", "Addr 2", "Addr 3", "City", "", "", "ZZ", "", "1234567890", "5", "Comments"]
  }

  before :each do
    @importer = FactoryBot(:company, system_code: "LERETURNS", importer: true)
    @us = FactoryBot(:country, iso_code: "US")
    @cdefs = described_class.prep_custom_definitions [:prod_part_number, :prod_suffix_indicator, :prod_exception_code, :prod_suffix, :prod_comments]
  end

  context "process lines" do
    before :each do
      @country = FactoryBot(:country, iso_code: row[12])
    end

    describe "process_product_line" do
      subject { described_class.new(nil) }

      it "processes a line from the parts file" do
        prod = subject.process_product_line row

        prod.reload

        expect(prod.unique_identifier).to eq "LERETURNS-#{row[0]}-#{row[1]}-#{row[2]}-#{row[3]}"
        us_class = prod.classifications.first
        expect(us_class).to_not be_nil
        expect(us_class.country.iso_code).to eq "US"
        tariff = us_class.tariff_records.first
        expect(tariff).to_not be_nil
        expect(tariff.hts_1).to eq row[14].gsub(".", "")

        expect(prod.custom_value(@cdefs[:prod_part_number])).to eq row[0]
        expect(prod.custom_value(@cdefs[:prod_suffix_indicator])).to eq row[1]
        expect(prod.custom_value(@cdefs[:prod_exception_code])).to eq row[2]
        expect(prod.custom_value(@cdefs[:prod_suffix])).to eq row[3]
        expect(prod.custom_value(@cdefs[:prod_comments])).to eq (row[15] + " | " + row[16])

        factory = prod.factories.first
        expect(factory).to_not be_nil
        expect(factory.company).to eq @importer
        expect(factory.products.first).to eq prod
        expect(factory.system_code).to eq row[4]
        expect(factory.name).to eq row[5]
        expect(factory.line_1).to eq row[6]
        expect(factory.line_2).to eq row[7]
        expect(factory.line_3).to eq row[8]
        expect(factory.city).to eq row[9]
        expect(factory.country).to eq @country
        expect(factory.country.iso_code).to eq row[12]
      end

      it "updates an existing product" do
        exist = FactoryBot(:product, unique_identifier: "LERETURNS-#{row[0]}-#{row[1]}-#{row[2]}-#{row[3]}", importer: @importer)
        c = exist.classifications.create! country: @us
        c.tariff_records.create! hts_1: "9876354321"

        prod = subject.process_product_line row
        expect(prod).to eq exist
        # Just make sure the tariff record got updated
        expect(prod.classifications.size).to eq 1
        expect(prod.classifications.first.tariff_records.size).to eq 1
        expect(prod.classifications.first.tariff_records.first.hts_1).to eq row[14].gsub(".", "")
      end

      it "updates an existing product adding existing factory" do
        exist = FactoryBot(:product, unique_identifier: "LERETURNS-#{row[0]}-#{row[1]}-#{row[2]}-#{row[3]}", importer: @importer)
        factory = FactoryBot(:address, company: @importer, system_code: row[4])

        prod = subject.process_product_line row
        expect(prod.factories.first).to eq factory

        # Also, we're not updating the addresses so, make sure the hash is the same
        expect(prod.factories.first.address_hash).to eq factory.address_hash
        expect(@importer.addresses.size).to eq 1
      end

      it "does not add an existing factory to a product" do
        factory = FactoryBot(:address, company: @importer, system_code: row[4])
        exist = FactoryBot(:product, unique_identifier: "LERETURNS-#{row[0]}-#{row[1]}-#{row[2]}-#{row[3]}", importer: @importer, factories: [factory])

        prod = subject.process_product_line row
        expect(prod.factories.size).to eq 1
        expect(prod.factories.first).to eq factory
      end
    end
  end

  describe "process_from_s3" do
    subject { described_class }
    let (:xl_client) { instance_double("OpenChain::XLClient") }
    let (:bucket) { "bucket" }
    let (:key) { "key" }
    let (:opts) { {} }

    before :each do
      expect(subject).to receive(:retrieve_file_data).with(bucket, key, opts).and_return xl_client
    end

    it "processes file via xl_client" do
      expect(xl_client).to receive(:all_row_values).and_yield(["Header"]).and_yield row
      subject.process_from_s3 bucket, key, opts

      # Just make sure a product was created
      expect(Product.where(unique_identifier: "LERETURNS-#{row[0]}-#{row[1]}-#{row[2]}-#{row[3]}", importer_id: @importer.id).first).to_not be_nil
    end
  end

  describe "parse_file" do
    subject { described_class }
    let (:xl_client) { instance_double("OpenChain::XLClient") }

    it "stringifies all values yielded" do
      # This is largely done so the style won't be a decimal value, so just test w/ the style column being a float.
      row[0] = 12.0

      expect(xl_client).to receive(:all_row_values).and_yield(["Header"]).and_yield row
      subject.parse_file xl_client, nil, nil
      expect(Product.where(unique_identifier: "LERETURNS-12-#{row[1]}-#{row[2]}-#{row[3]}", importer_id: @importer.id).first).to_not be_nil
    end
  end

  describe "integration_folder" do
    it "uses correct folder" do
      expect(described_class.integration_folder).to eq ["www-vfitrack-net/_lands_end_products", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_lands_end_products"]
    end
  end

  describe "process_from_s3" do
    it "handles integration client parser values" do
      expect(OpenChain::XLClient).to receive(:new).with('path/to/file.txt', {bucket: "bucket"}).and_return double("XLClient")
      expect_any_instance_of(described_class).to receive(:process_file)

      described_class.process_from_s3 'bucket', 'path/to/file.txt'
    end
  end

  describe "initialize" do
    it "raises an error if importer account isn't present" do
      expect {described_class.new nil, 'BLAH'}.to raise_error "Invalid importer system code BLAH."
    end
  end
end