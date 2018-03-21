describe OpenChain::CustomHandler::AnnInc::AnnCommercialInvoiceXmlParser do

  let (:xml) { IO.read "spec/fixtures/files/ann_commercial_invoice.xml"}
  let (:document) { REXML::Document.new xml }
  let!(:ann) { Factory(:importer, system_code: "ATAYLOR", alliance_customer_number: "ATAYLOR") }
  let!(:country) { Factory(:country, iso_code: "CN") }
  let!(:country2) { Factory(:country, iso_code: "ID") }

  before do
    # has to be mocked because the output of make_hash_key is dependent on address.country_id
    allow(Address).to receive(:make_hash_key) { |val| Digest::MD5.hexdigest(val.name) }
  end

  describe "parse" do

    def check_output
      invoice = Invoice.first

      #header
      expect(invoice.importer).to eq ann
      expect(invoice.country_origin).to eq country
      expect(invoice.exchange_rate).to eq 2
      expect(invoice.gross_weight).to eq 731.75
      expect(invoice.gross_weight_uom).to eq "KG"
      expect(invoice.invoice_date).to eq Date.new(2017,4,9)
      expect(invoice.invoice_number).to eq "435118117HK"
      expect(invoice.currency).to eq "USD"
      expect(invoice.invoice_total_foreign).to eq 14568.54
      expect(invoice.invoice_total_domestic).to eq 7284.27

      vendor = invoice.vendor
      expect(vendor.name).to eq "PT. ERATEX (HONG KONG)"
      expect(vendor.system_code).to eq "ATAYLOR-91ebc99a3a87fa077a9c65be84883977"
      
      expect(vendor.addresses.count).to eq 1
      vendor_address = vendor.addresses.first
      expect(vendor_address.name).to eq vendor.name
      expect(vendor_address.line_1).to eq "UNIT E 11/F, EFFORT INDUSTRIAL"
      expect(vendor_address.line_2).to eq "100 Easy St"
      expect(vendor_address.city).to eq "Hong Kong"
      expect(vendor_address.country).to eq country

      factory = invoice.factory
      expect(factory.name).to eq "PT Eratex Djaja Ltd Tbk."
      expect(factory.system_code).to eq "ATAYLOR-15d59677bdde468e04d508e989ba6eb7"

      expect(factory.addresses.count).to eq 1
      factory_address = factory.addresses.first
      expect(factory_address.name).to eq factory.name
      expect(factory_address.line_1).to eq "Jl. Soekarno Hatta No. 23"
      expect(factory_address.line_2).to eq "200 Hard St"
      expect(factory_address.city).to eq "Probolinggo"
      expect(factory_address.country).to eq country2
      
      expect(invoice.country_origin).to eq country

      #line
      expect(invoice.invoice_lines.count).to eq 1
      line = invoice.invoice_lines.first

      expect(line.air_sea_discount).to eq 4
      expect(line.department).to eq "226"
      expect(line.early_pay_discount).to eq 2
      expect(line.trade_discount).to eq 3
      expect(line.fish_wildlife).to eq false
      expect(line.line_number).to eq 1
      expect(line.middleman_charge).to eq 5
      expect(line.net_weight).to eq 669.8
      expect(line.net_weight_uom).to eq "KG"
      expect(line.part_description).to eq "ladies woven 98% cotton 2% spandex pant, white denim"
      expect(line.part_number).to eq "419488"
      expect(line.po_number).to eq "6238635"
      expect(line.pieces).to eq 1460
      expect(line.quantity).to eq 1457
      expect(line.quantity_uom).to eq "NO"
      expect(line.unit_price).to eq 11.09
      expect(line.value_foreign).to eq 16187.27
      expect(line.value_domestic).to eq 8093.64
    end

    it "parses a commercial invoice" do
      expect{ subject.parse(document) }.to change(Invoice, :count ).from(0).to 1
      check_output
    end

    it "replaces earlier parse" do
      subject.parse(document)
      expect{ subject.parse(document) }.to_not change(Invoice, :count)
      check_output
    end
  
    it "errors if importer code other than 'ANNTAYNYC' is found" do
      importer_code = REXML::XPath.first(document, "//OrganizationAddress[AddressType='Importer']/OrganizationCode")
      importer_code.text = "ACME"
      expect{ subject.parse(document) }.to raise_error "Unexpected importer code: ACME"
    end
  end
end
