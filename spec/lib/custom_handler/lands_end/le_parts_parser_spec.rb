require 'spec_helper'

describe OpenChain::CustomHandler::LandsEnd::LePartsParser do

  before :each do
    @importer = Factory(:company, system_code: "LERETURNS", importer: true)
    @us = Factory(:country, iso_code: "US")
    @cdefs = described_class.prep_custom_definitions described_class::CUSTOM_DEFINITION_INSTRUCTIONS.keys
  end

  context "process lines" do
    before :each do
      @row = ['style', 'suf ind', 'exc code', 'suf', 'Factory', "Factory Name", "Addr 1", "Addr 2", "Addr 3", "City", "", "", "ZZ", "", "1234567890", "5", "Comments"]
      @country = Factory(:country, iso_code: @row[12])
    end

    describe "process_product_line" do
    
      it "processes a line from the parts file" do
        prod = described_class.new(nil).process_product_line @row

        prod.reload

        expect(prod.unique_identifier).to eq "LERETURNS-#{@row[0]}-#{@row[1]}-#{@row[2]}-#{@row[3]}"
        us_class = prod.classifications.first
        expect(us_class).to_not be_nil
        expect(us_class.country.iso_code).to eq "US"
        tariff = us_class.tariff_records.first
        expect(tariff).to_not be_nil
        expect(tariff.hts_1).to eq @row[14].gsub(".", "")

        expect(prod.get_custom_value(@cdefs[:part_number]).value).to eq @row[0]
        expect(prod.get_custom_value(@cdefs[:suffix_indicator]).value).to eq @row[1]
        expect(prod.get_custom_value(@cdefs[:exception_code]).value).to eq @row[2]
        expect(prod.get_custom_value(@cdefs[:suffix]).value).to eq @row[3]
        expect(prod.get_custom_value(@cdefs[:comments]).value).to eq (@row[15] + " | " + @row[16])

        factory = prod.factories.first
        expect(factory).to_not be_nil
        expect(factory.company).to eq @importer
        expect(factory.products.first).to eq prod
        expect(factory.system_code).to eq @row[4]
        expect(factory.name).to eq @row[5]
        expect(factory.line_1).to eq @row[6]
        expect(factory.line_2).to eq @row[7]
        expect(factory.line_3).to eq @row[8]
        expect(factory.city).to eq @row[9]
        expect(factory.country).to eq @country
        expect(factory.country.iso_code).to eq @row[12]
      end

      it "updates an existing product" do
        exist = Factory(:product, unique_identifier: "LERETURNS-#{@row[0]}-#{@row[1]}-#{@row[2]}-#{@row[3]}", importer: @importer)
        c = exist.classifications.create! country: @us
        c.tariff_records.create! hts_1: "9876354321"

        prod = described_class.new(nil).process_product_line @row
        expect(prod).to eq exist
        # Just make sure the tariff record got updated
        expect(prod.classifications.size).to eq 1
        expect(prod.classifications.first.tariff_records.size).to eq 1
        expect(prod.classifications.first.tariff_records.first.hts_1).to eq @row[14].gsub(".", "")
      end

      it "updates an existing product adding existing factory" do
        exist = Factory(:product, unique_identifier: "LERETURNS-#{@row[0]}-#{@row[1]}-#{@row[2]}-#{@row[3]}", importer: @importer)
        factory = Factory(:address, company: @importer, system_code: @row[4])

        prod = described_class.new(nil).process_product_line @row
        expect(prod.factories.first).to eq factory

        # Also, we're not updating the addresses so, make sure the hash is the same
        expect(prod.factories.first.address_hash).to eq factory.address_hash
        expect(@importer.addresses.size).to eq 1
      end

      it "does not add an existing factory to a product" do
        factory = Factory(:address, company: @importer, system_code: @row[4])
        exist = Factory(:product, unique_identifier: "LERETURNS-#{@row[0]}-#{@row[1]}-#{@row[2]}-#{@row[3]}", importer: @importer, factories: [factory])
        
        prod = described_class.new(nil).process_product_line @row
        expect(prod.factories.size).to eq 1
        expect(prod.factories.first).to eq factory
      end
    end

    describe "process_file" do
      before :each do
        @xl_client = double("XLClient")
      end

      it "processes file via xl_client" do
        @xl_client.should_receive(:all_row_values).and_yield(["Header"]).and_yield @row
        described_class.new(@xl_client).process_file

        # Just make sure a product was created
        expect(Product.where(unique_identifier: "LERETURNS-#{@row[0]}-#{@row[1]}-#{@row[2]}-#{@row[3]}", importer_id: @importer.id).first).to_not be_nil
      end

      it "stringifies all values yielded" do
        # This is largely done so the style won't be a decimal value, so just test w/ the style column being a float.
        @row[0] = 12.0

        @xl_client.should_receive(:all_row_values).and_yield(["Header"]).and_yield @row
        described_class.new(@xl_client).process_file
        expect(Product.where(unique_identifier: "LERETURNS-12-#{@row[1]}-#{@row[2]}-#{@row[3]}", importer_id: @importer.id).first).to_not be_nil
      end
    end
  end
 
  describe "integration_folder" do 
    it "uses correct folder" do
      expect(described_class.integration_folder).to eq ["/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_lands_end_products"]
    end
  end

  describe "process_from_s3" do
    it "handles integration client parser values" do
      OpenChain::XLClient.should_receive(:new).with('path/to/file.txt', {bucket: "bucket"}).and_return double("XLClient")
      described_class.any_instance.should_receive(:process_file)

      described_class.process_from_s3 'bucket', 'path/to/file.txt'
    end
  end

  describe "initialize" do
    it "raises an error if importer account isn't present" do
      expect {described_class.new nil, 'BLAH'}.to raise_error "Invalid importer system code BLAH."
    end
  end
end