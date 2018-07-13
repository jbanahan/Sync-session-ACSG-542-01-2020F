require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::KewillProductGenerator do

  subject { described_class.new "CUST"}

  describe "write_row_to_xml" do

    let (:row) {
      # This is what a file row without FDA information will look like (description should upcase)
      ["STYLE", "description", "1234567890", "CO", "BRAND"]
    }
    
    let (:fda_row) {
      row + ["Y", "FDACODE", "UOM", "CP", "MID", "SID", "FDADESC", "ESTNO", "Dom1", "Dom2", "Dom3", "Name", "Phone", "COD", "AFFCOMP", "F"]
    }

    let (:parent) { REXML::Document.new("<root></root>").root }

    it "writes XML data to given element" do
      subject.write_row_to_xml parent, 1, row
      expect(parent.text "part/id/partNo").to eq "STYLE"
      expect(parent.text "part/id/custNo").to eq "CUST"
      expect(parent.text "part/id/dateEffective").to eq "20140101"
      expect(parent.text "part/dateExpiration").to eq "20991231"
      expect(parent.text "part/styleNo").to eq "STYLE"
      expect(parent.text "part/countryOrigin").to eq "CO"
      expect(parent.text "part/descr").to eq "DESCRIPTION"
      expect(parent.text "part/productLine").to eq "BRAND"
      expect(parent.text "part/CatTariffClassList/CatTariffClass/seqNo").to eq "1"
      expect(parent.text "part/CatTariffClassList/CatTariffClass/tariffNo").to eq "1234567890"

      # Make sure no FDA information was written - even though blank tags would techincally be fine
      # I want to make sure the size of these files is as small as possible to allow for more data in them before
      # crashing the Kewill processor due to memory size needed to handle a large XML file
      expect(REXML::XPath.first parent, "part/manufacturerId").to be_nil
      expect(REXML::XPath.first parent, "part/CatTariffClassList/CatTariffClass/CatFdaEsList").to be_nil
    end

    it "writes FDA data if present" do
      subject.write_row_to_xml parent, 1, fda_row

      expect(parent.text "part/manufacturerId").to eq "MID"
      fda = REXML::XPath.first parent, "part/CatTariffClassList/CatTariffClass/CatFdaEsList/CatFdaEs"
      expect(fda).not_to be_nil
      expect(fda.text "partNo").to eq "STYLE"
      expect(fda.text "styleNo").to eq "STYLE"
      expect(fda.text "custNo").to eq "CUST"
      expect(fda.text "dateEffective").to eq "20140101"

      expect(fda.text "seqNo").to eq "1"
      expect(fda.text "fdaSeqNo").to eq "1"
      expect(fda.text "productCode").to eq "FDACODE"
      expect(fda.text "fdaUom1").to eq "UOM"
      expect(fda.text "countryProduction").to eq "CP"
      expect(fda.text "manufacturerId").to eq "MID"
      expect(fda.text "shipperId").to eq "SID"
      expect(fda.text "desc1Ci").to eq "FDADESC"
      expect(fda.text "establishmentNo").to eq "ESTNO"
      expect(fda.text "containerDimension1").to eq "Dom1"
      expect(fda.text "containerDimension2").to eq "Dom2"
      expect(fda.text "containerDimension3").to eq "Dom3"
      expect(fda.text "contactName").to eq "Name"
      expect(fda.text "contactPhone").to eq "Phone"
      expect(fda.text "cargoStorageStatus").to eq "F"

      aff = REXML::XPath.first fda, "CatFdaEsComplianceList/CatFdaEsCompliance"
      expect(aff).not_to be_nil
      expect(aff.text "partNo").to eq "STYLE"
      expect(aff.text "styleNo").to eq "STYLE"
      expect(aff.text "custNo").to eq "CUST"
      expect(aff.text "dateEffective").to eq "20140101"
      expect(aff.text "seqNo").to eq "1"
      expect(aff.text "fdaSeqNo").to eq "1"
      expect(aff.text "seqNoEntryOrder").to eq "1"
      expect(aff.text "complianceCode").to eq "COD"
      expect(aff.text "complianceQualifier").to eq "AFFCOMP"
    end

    it "trims non-key fields to size" do
      row = []
      fda_row.each_with_index do |v, x|
        # Don't pad fields that will error if too long (style, tariff) or FDA Flag
        v = v.ljust(80, '-') unless [0, 2, 5].include? x
        row << v
      end

      subject.write_row_to_xml parent, 1, row

      expect(parent.text "part/id/partNo").to eq "STYLE"
      expect(parent.text "part/id/custNo").to eq "CUST"
      expect(parent.text "part/id/dateEffective").to eq "20140101"
      expect(parent.text "part/styleNo").to eq "STYLE"
      expect(parent.text "part/countryOrigin").to eq "CO"
      expect(parent.text "part/descr").to eq "DESCRIPTION-----------------------------"
      expect(parent.text "part/productLine").to eq "BRAND-------------------------"
      expect(parent.text "part/manufacturerId").to eq "MID------------"
      fda = REXML::XPath.first parent, "part/CatTariffClassList/CatTariffClass/CatFdaEsList/CatFdaEs"
      expect(fda).not_to be_nil
      expect(fda.text "productCode").to eq "FDACODE"
      expect(fda.text "fdaUom1").to eq "UOM-"
      expect(fda.text "countryProduction").to eq "CP"
      expect(fda.text "manufacturerId").to eq "MID------------"
      expect(fda.text "shipperId").to eq "SID------------"
      expect(fda.text "desc1Ci").to eq "FDADESC---------------------------------------------------------------"
      expect(fda.text "establishmentNo").to eq "ESTNO-------"
      expect(fda.text "containerDimension1").to eq "Dom1"
      expect(fda.text "containerDimension2").to eq "Dom2"
      expect(fda.text "containerDimension3").to eq "Dom3"
      expect(fda.text "contactName").to eq "Name------"
      expect(fda.text "contactPhone").to eq "Phone-----"
      expect(fda.text "cargoStorageStatus").to eq "F"

      aff = REXML::XPath.first fda, "CatFdaEsComplianceList/CatFdaEsCompliance"
      expect(aff).not_to be_nil
      expect(aff.text "complianceQualifier").to eq "AFFCOMP------------------"
    end

    it "raises an error if part number is too long" do
      row[0] = "12345678901234567890123456789012345678901"

      expect { subject.write_row_to_xml parent, 1, row }.to raise_error "partNo cannot be over 40 characters.  It was '12345678901234567890123456789012345678901'."
    end

    it "raises an error if tariff # is too long" do
      row[2] = "12345678901"
      expect { subject.write_row_to_xml parent, 1, row }.to raise_error "tariffNo cannot be over 10 characters.  It was '12345678901'."
    end

    it "sends multiple tariffs" do
      # Include FDA information, so we know it's written to both classifications
      fda_row[2] = "12345678*~*987654321"
      subject.write_row_to_xml parent, 1, fda_row

      tariffs = []
      parent.elements.each("part/CatTariffClassList/CatTariffClass") {|el| tariffs << el}
      expect(tariffs.length).to eq 2

      t = tariffs.first
      expect(t.text "seqNo").to eq "1"
      expect(t.text "tariffNo").to eq "12345678"
      # Just check that the fda info is present and has the correct seq identifier
      expect(t.text "CatFdaEsList/CatFdaEs/seqNo").to eq "1"
      expect(t.text "CatFdaEsList/CatFdaEs/fdaSeqNo").to eq "1"
      expect(t.text "CatFdaEsList/CatFdaEs/productCode").to eq "FDACODE"

      t = tariffs.second
      expect(t.text "seqNo").to eq "2"
      expect(t.text "tariffNo").to eq "987654321"
      expect(t.text "CatFdaEsList/CatFdaEs/seqNo").to eq "2"
      expect(t.text "CatFdaEsList/CatFdaEs/fdaSeqNo").to eq "1"
      expect(t.text "CatFdaEsList/CatFdaEs/productCode").to eq "FDACODE"
    end

    it "allows for default values to be sent at all levels" do
      opts = {defaults: 
                {
                  "CatCiLine" => {
                    "printPartNo7501" => "Y",
                    "process9802" => "N"},  
                  "CatTariffClass" => {
                    "ultimateConsignee" => "CONS"},
                  "CatFdaEs" => {
                    "abiPriorNotice" => "Y"}, 
                  "CatFdaEsCompliance" => {
                    "assembler" => "ASS"}
                }
              }

      gen = described_class.new "CUST", opts

      gen.write_row_to_xml parent, 1, fda_row
      expect(parent.text "part/printPartNo7501").to eq "Y"
      expect(parent.text "part/process9802").to eq "N"
      expect(parent.text "part/CatTariffClassList/CatTariffClass/ultimateConsignee").to eq "CONS"
      expect(parent.text "part/CatTariffClassList/CatTariffClass/CatFdaEsList/CatFdaEs/abiPriorNotice").to eq "Y"
      expect(parent.text "part/CatTariffClassList/CatTariffClass/CatFdaEsList/CatFdaEs/CatFdaEsComplianceList/CatFdaEsCompliance/assembler").to eq "ASS"
    end

    context "with special tariffs" do
      let! (:special_tariff) { SpecialTariffCrossReference.create! hts_number: "1234567890", special_hts_number: "0987654321", country_origin_iso: "CO", effective_date_start: (Time.zone.now.to_date), effective_date_end: (Time.zone.now.to_date + 1.day) }

      it "includes special tariffs as first tariff record if present" do
        subject.write_row_to_xml parent, 1, row

        tariffs = []
        parent.elements.each("part/CatTariffClassList/CatTariffClass") {|el| tariffs << el}
        expect(tariffs.length).to eq 2

        t = tariffs.first
        expect(t.text "seqNo").to eq "1"
        expect(t.text "tariffNo").to eq "0987654321"

        t = tariffs.second
        expect(t.text "seqNo").to eq "2"
        expect(t.text "tariffNo").to eq "1234567890"
      end

      it "allows setting default country of origin to override blank country of origins" do
        opts = {default_special_tariff_country_origin: "CO"}
        gen = described_class.new "CUST", opts
        # Blank the "query" result's country of origin, to make sure the default one is being used
        row[3] = nil

        gen.write_row_to_xml parent, 1, row

        tariffs = []
        parent.elements.each("part/CatTariffClassList/CatTariffClass") {|el| tariffs << el}
        expect(tariffs.length).to eq 2

        t = tariffs.first
        expect(t.text "seqNo").to eq "1"
        expect(t.text "tariffNo").to eq "0987654321"

        t = tariffs.second
        expect(t.text "seqNo").to eq "2"
        expect(t.text "tariffNo").to eq "1234567890"
      end

      it "allows disabling special tariff lookups" do
        opts = {disable_special_tariff_lookup: true}
        gen = described_class.new "CUST", opts

        gen.write_row_to_xml parent, 1, row

        tariffs = []
        parent.elements.each("part/CatTariffClassList/CatTariffClass") {|el| tariffs << el}
        expect(tariffs.length).to eq 1
      end
    end

    it "allows style truncation if instructed" do
      opts = {allow_style_truncation: true}
      gen = described_class.new "CUST", opts

      row[0] = "12345678901234567890123456789012345678901234567890"

      gen.write_row_to_xml parent, 1, row

      expect(parent.text "part/id/partNo").to eq "1234567890123456789012345678901234567890"
    end

  end

  describe "run_schedulable" do
    subject { described_class }
    let (:product) { create_product "Style" }
    let (:us) { Factory(:country, iso_code: "US") }
    let (:importer) { Factory(:importer, alliance_customer_number: "CUST") }

    def create_product style, part_number: true
      p = Factory(:product, unique_identifier: "CUST-#{style}", importer: importer)
      c = Factory(:classification, product: p, country: us)
      c.tariff_records.create! hts_1: "1234567890"

      p.update_custom_value!(described_class.new(nil).custom_defs[:prod_part_number], style) if part_number
      p
    end

    it "finds product and ftps a file" do
      product
      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      # Make sure write_row_to_xml is actually being called, since we're relying on that to provide all the
      # xml detail (and it's thoroughly tested above)
      expect_any_instance_of(subject).to receive(:write_row_to_xml).and_call_original

      now = Time.zone.now
      Timecop.freeze(now) do 
        subject.run_schedulable "alliance_customer_number" => "CUST"
      end

      product.reload

      expect(product.sync_records.length).to eq 1
      sr = product.sync_records.first

      expect(sr.trading_partner).to eq "Alliance"

      expect(data).not_to be_nil
      doc = REXML::Document.new(data)

      # Validate all the "header" xml document stuff that gets added..
      expect(REXML::XPath.first doc, "/requests/request/kcData/parts/part").not_to be_nil
      
      # Make sure the doc base is built correctly
      r = doc.root
      expect(r.text "password").to eq "lk5ijl9"
      expect(r.text "userID").to eq "kewill_edi"
      expect(r.text "request/action").to eq "KC"
      expect(r.text "request/category").to eq "Parts"
      expect(r.text "request/subAction").to eq "CreateUpdate"

      # Validate that our product data made it in (we've thoroughly tested the xml output in write_row_to_xml, so just validate that that stuff made it in here)
      expect(doc.text "/requests/request/kcData/parts/part/id/partNo").to eq "Style"

      importer.reload
      expect(importer.last_alliance_product_push_at.to_i).to eq now.to_i
    end

    it "finds product using importer_system_code if given" do
      product
      importer.update_attributes! alliance_customer_number: nil, system_code: "SYSCODE"
      expect_any_instance_of(subject).to receive(:ftp_file)

      now = Time.zone.now
      Timecop.freeze(now) do 
        subject.run_schedulable "alliance_customer_number" => "CUST", "importer_system_code": "SYSCODE"
      end
      product.reload

      expect(product.sync_records.length).to eq 1
    end

    it "ftps repeatedly until all producs are sent" do
      # Create a second product and then set the max products per file to 1...we should get two files ftp'ed
      product
      product2 = create_product "Style2"

      expect_any_instance_of(subject).to receive(:ftp_file).exactly(2).times
      allow_any_instance_of(subject).to receive(:max_products_per_file).and_return 1

      subject.run_schedulable "alliance_customer_number" => "CUST"

      product.reload
      product2.reload

      expect(product.sync_records.length).to eq 1
      expect(product2.sync_records.length).to eq 1
    end

    it "errors if invalid customer number given" do
      expect { subject.run_schedulable "alliance_customer_number" => "Invalid" }.to raise_error "No importer found with Kewill customer number 'Invalid'."
    end

    it "errors if invalid system code given" do
      expect { subject.run_schedulable "alliance_customer_number" => "Invalid", "importer_system_code" => "SYSCODE" }.to raise_error "No importer found with Importer System Code 'SYSCODE'."
    end

    it "strips leading zeros on part number" do
      p = create_product("000001")
      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      subject.run_schedulable "alliance_customer_number" => "CUST", "strip_leading_zeros" => true
      expect(data).not_to be_nil
      doc = REXML::Document.new(data)

      expect(doc.text "/requests/request/kcData/parts/part/id/partNo").to eq "1"
    end

    it "uses unique_identifier instead of part number" do
      p = create_product("000001", part_number: false)
      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      subject.run_schedulable "alliance_customer_number" => "CUST", "use_unique_identifier" => true
      expect(data).not_to be_nil
      doc = REXML::Document.new(data)

      expect(doc.text "/requests/request/kcData/parts/part/id/partNo").to eq "CUST-000001"
    end

    it "allows finding products without importer id restrictions" do
      p = create_product("000001")
      p.update_attributes! importer_id: nil

      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      subject.run_schedulable "alliance_customer_number" => "CUST", "disable_importer_check" => true

      expect(data).not_to be_nil
      doc = REXML::Document.new(data)

      expect(doc.text "/requests/request/kcData/parts/part/id/partNo").to eq "000001"
    end

    it "allows for sending multiple tarifs" do
      p = create_product("000001")
      t2 = p.classifications.first.tariff_records.create! hts_1: "9876543210"

      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      subject.run_schedulable "alliance_customer_number" => "CUST", "allow_multiple_tariffs" => true

      doc = REXML::Document.new(data)
      expect(doc.text "/requests/request/kcData/parts/part/CatTariffClassList/CatTariffClass[seqNo = '1']/tariffNo").to eq "1234567890"
      expect(doc.text "/requests/request/kcData/parts/part/CatTariffClassList/CatTariffClass[seqNo = '2']/tariffNo").to eq "9876543210"
    end
  end
end