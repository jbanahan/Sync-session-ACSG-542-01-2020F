require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator do

  let(:entry_data) {
    e = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new '597549', 'SALOMON', []
    i = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new '15MSA10', Date.new(2015,11,1), []
    i.non_dutiable_amount = BigDecimal("5")
    i.add_to_make_amount = BigDecimal("25")
    e.invoices << i
    l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
    l.part_number = "PART"
    l.country_of_origin = "PH"
    l.gross_weight = BigDecimal("78")
    l.pieces = BigDecimal("93")
    l.hts = "4202.92.3031"
    l.foreign_value = BigDecimal("3177.86")
    l.quantity_1 = BigDecimal("93")
    l.quantity_2 = BigDecimal("52")
    l.po_number = "5301195481"
    l.first_sale = BigDecimal("218497.20")
    l.department = 1.0
    l.add_to_make_amount = BigDecimal("15")
    l.non_dutiable_amount = BigDecimal("20")
    l.cotton_fee_flag = ""
    l.mid = "PHMOUINS2106BAT"
    l.cartons = BigDecimal("10")
    l.spi = "JO"
    l.unit_price = BigDecimal("15.50")
    i.invoice_lines << l

    l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
    l.part_number = "PART2"
    l.country_of_origin = "PH"
    l.gross_weight = BigDecimal("78")
    l.pieces = BigDecimal("93")
    l.hts = "4202.92.3031"
    l.foreign_value = BigDecimal("3177.86")
    l.quantity_1 = BigDecimal("93")
    l.quantity_2 = BigDecimal("52")
    l.po_number = "5301195481"
    l.first_sale = BigDecimal("218497.20")
    l.department = 1.0
    l.add_to_make_amount = BigDecimal("15")
    l.non_dutiable_amount = BigDecimal("20")
    l.cotton_fee_flag = ""
    l.mid = "PHMOUINS2106BAT"
    l.cartons = BigDecimal("20")
    l.spi = "JO"
    l.unit_price = BigDecimal("15.50")
    i.invoice_lines << l

    e
  }


  describe "generate_entry_xml" do
    let (:xml_root) { REXML::Document.new("<root></root>").root }
    let (:buyer) { 
      c = Factory(:importer, alliance_customer_number: "BUY")
      c.addresses.create! system_code: "1", name: "Buyer", line_1: "Addr1", line_2: "Addr2", city: "City", state: "ST", country: Factory(:country, iso_code: "US"), postal_code: "00000"

      c
    }

    let (:mid) {
      ManufacturerId.create! mid: "MID", name: "Manufacturer", address_1: "Addr1", address_2: "Addr2", city: "City", country: "CO", postal_code: "00000", active: true
    }

    it "generates entry data to given xml element" do
      buyer
      mid
      entry_data.invoices.first.invoice_lines.first.buyer_customer_number = "BUY"
      entry_data.invoices.first.invoice_lines.first.seller_mid = "MID"

      subject.generate_entry_xml xml_root, entry_data, add_entry_info: false

      t = REXML::XPath.first xml_root, "/root/ediShipment/EdiInvoiceHeaderList"
      expect(t).not_to be_nil


      # Make sure entry / shipment information is not in the xml
      expect(t.text "EdiShipmentHeader/custNo").to be_nil

      t = REXML::XPath.first t, "EdiInvoiceHeader"
      expect(t.text "manufacturerId").to eq "597549"
      expect(t.text "commInvNo").to eq "15MSA10"
      expect(t.text "dateInvoice").to eq "20151101"
      expect(t.text "custNo").to eq "SALOMON"
      expect(t.text "nonDutiableAmt").to eq "500"
      expect(t.text "addToMakeAmt").to eq "2500"
      expect(t.text "currency").to eq "USD"
      expect(t.text "exchangeRate").to eq "1000000"
      expect(t.text "qty").to eq "30"
      expect(t.text "uom").to eq "CTNS"

      l = REXML::XPath.first t, "EdiInvoiceLinesList/EdiInvoiceLines"
      expect(l).not_to be_nil

      expect(l.text "manufacturerId").to eq "597549"
      expect(l.text "commInvNo").to eq "15MSA10"
      expect(l.text "dateInvoice").to eq "20151101"
      expect(l.text "custNo").to eq "SALOMON"
      expect(l.text "commInvLineNo").to eq '10'
      expect(l.text "partNo").to eq "PART"
      expect(l.text "countryOrigin").to eq "PH"
      expect(l.text "weightGross").to eq "78"
      expect(l.text "kilosPounds").to eq "KG"
      expect(l.text "qtyCommercial").to eq "93000"
      expect(l.text "uomCommercial").to eq "PCS"
      expect(l.text "uomVolume").to eq "M3"
      expect(l.text "unitPrice").to eq "15500"
      expect(l.text "tariffNo").to eq "4202923031"
      expect(l.text "valueForeign").to eq "317786"
      expect(l.text "qty1Class").to eq "9300"
      expect(l.text "qty2Class").to eq "5200"
      expect(l.text "purchaseOrderNo").to eq "5301195481"
      expect(l.text "custRef").to eq "5301195481"
      expect(l.text "contract").to eq "218497.2"
      expect(l.text "department").to eq "1"
      expect(l.text "spiPrimary").to eq "JO"
      expect(l.text "nonDutiableAmt").to eq "2000"
      expect(l.text "addToMakeAmt").to eq "1500"
      expect(l.text "exemptionCertificate").to be_nil
      expect(l.text "manufacturerId2").to eq "PHMOUINS2106BAT"
      expect(l.text "cartons").to eq "1000"

      parties = REXML::XPath.first l, "EdiInvoicePartyList"
      expect(parties).not_to be_nil
      buyer = REXML::XPath.first l, "EdiInvoicePartyList/EdiInvoiceParty[partiesQualifier = 'BY']"
      expect(buyer).not_to be_nil
      expect(buyer.text "commInvNo").to eq "15MSA10"
      expect(buyer.text "commInvLineNo").to eq "10"
      expect(buyer.text "dateInvoice").to eq "20151101"
      expect(buyer.text "manufacturerId").to eq "597549"
      expect(buyer.text "address1").to eq "Addr1"
      expect(buyer.text "address2").to eq "Addr2"
      expect(buyer.text "city").to eq "City"
      expect(buyer.text "country").to eq "US"
      expect(buyer.text "countrySubentity").to eq "ST"
      expect(buyer.text "custNo").to eq "BUY"
      expect(buyer.text "name").to eq "Buyer"
      expect(buyer.text "zip").to eq "00000"

      seller = REXML::XPath.first l, "EdiInvoicePartyList/EdiInvoiceParty[partiesQualifier = 'SE']"
      expect(seller).not_to be_nil
      expect(seller.text "commInvNo").to eq "15MSA10"
      expect(seller.text "commInvLineNo").to eq "10"
      expect(seller.text "dateInvoice").to eq "20151101"
      expect(seller.text "manufacturerId").to eq "597549"
      expect(seller.text "address1").to eq "Addr1"
      expect(seller.text "address2").to eq "Addr2"
      expect(seller.text "city").to eq "City"
      expect(seller.text "country").to eq "CO"
      expect(seller.text "name").to eq "Manufacturer"
      expect(seller.text "zip").to eq "00000"
    end

    it "generates 999999999 as cert value when cotton fee flag is true" do
      mid
      d = entry_data
      d.invoices.first.invoice_lines.first.cotton_fee_flag = "Y"
      subject.generate_entry_xml xml_root, entry_data

      t = REXML::XPath.first xml_root, "/root/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
      expect(t).not_to be_nil
      expect(t.text "exemptionCertificate").to eq "999999999"
    end

    it "uses ascii encoding for string data w/ ? as a replacement char" do
      d = entry_data
      d.invoices.first.invoice_number = "Test ¶"

      subject.generate_entry_xml xml_root, entry_data

      t = REXML::XPath.first xml_root, "/root/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader"
      expect(t).not_to be_nil
      expect(t.text "commInvNo").to eq "Test ?"
    end

    it "allows using alternate addresses for buyers" do
      buyer
      mid
      entry_data.invoices.first.invoice_lines.first.buyer_customer_number = "BUY"
      entry_data.invoices.first.invoice_lines.first.seller_mid = "MID"
      buyer.addresses.create! system_code: "2", name: "Buyer 2", line_1: "Addr1", line_2: "Addr2", city: "City", state: "ST", postal_code: "00000"
      entry_data.invoices.first.invoice_lines.first.buyer_customer_number = "BUY-2"

      subject.generate_entry_xml xml_root, entry_data

      buyer = REXML::XPath.first xml_root, "/root/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines/EdiInvoicePartyList/EdiInvoiceParty[partiesQualifier = 'BY']"
      expect(buyer).not_to be_nil
      expect(buyer.text "name").to eq "Buyer 2"
    end

    it "raises an error if an MID is in the data but not in VFI Track" do
      entry_data.invoices.first.invoice_lines.first.seller_mid = "MID"
      expect {subject.generate_entry_xml xml_root, entry_data}.to raise_error OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError, "No MID exists in VFI Track for 'MID'."
    end

    it "raises an error if an MID references an inactive MID" do
      entry_data.invoices.first.invoice_lines.first.seller_mid = "MID"
      mid
      mid.active = false
      mid.save!
      expect {subject.generate_entry_xml xml_root, entry_data}.to raise_error OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError, "MID 'MID' is not an active MID."
    end

    it "raises an error if a Buyer is in the data but not in VFI Track" do
      entry_data.invoices.first.invoice_lines.first.buyer_customer_number = "BUY"
      expect {subject.generate_entry_xml xml_root, entry_data}.to raise_error OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError, "No Customer Address # '1' found for 'BUY'."
    end
  end

  describe "generate_and_send" do
    it "generates data to a tempfile and ftps it" do
      filename = nil
      data = nil
      expect(subject).to receive(:ftp_file) do |temp|
        data = temp.read
        filename = File.basename(temp.path)
      end
      subject.generate_and_send [entry_data]

      doc = REXML::Document.new data
      expect(REXML::XPath.first doc, "/requests/request/kcData/ediShipments/ediShipment").not_to be_nil
      expect(filename).to start_with "CI_Load_597549_"
      expect(filename).to end_with ".xml"

      # Make sure the doc base is built correctly
      r = doc.root
      expect(r.text "password").to eq "lk5ijl9"
      expect(r.text "userID").to eq "kewill_edi"
      expect(r.text "request/action").to eq "KC"
      expect(r.text "request/category").to eq "EdiShipment"
      expect(r.text "request/subAction").to eq "CreateUpdate"
    end

    it "catches data overflow errors and re-raises them as MissingCiLoadDataError" do
      # File number overflows at 15 chars
      entry_data.file_number = "1234567890123456"

      ex = nil
      begin
        subject.generate_and_send [entry_data]
        fail("Should have raised an error.")
      rescue OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError => e
        ex = e
      end

      expect(ex.message).to eq "String '#{entry_data.file_number}' is longer than 15 characters"
      expect(ex.backtrace).not_to be_blank
    end
  end

  describe "ftp_credentials" do
    it "uses credentials for connect.vfitrack.net" do
      expect(subject.ftp_credentials).to eq(
        {server: 'connect.vfitrack.net', username: 'ecs', password: 'wzuomlo', folder: "kewill_edi/to_kewill", protocol: 'sftp', port: 2222}
      )
    end
  end

  describe "generate_and_send_invoices" do
    let (:importer) {
      Company.new importer: true, alliance_customer_number: "IMP"
    }
    let (:invoice) {
      i = CommercialInvoice.new
      i.invoice_number = "INV#"
      i.invoice_date = Date.new(2016, 5, 9)
      i.importer = importer

      l = i.commercial_invoice_lines.build
      l.po_number = "PO"
      l.part_number = "PART"
      l.quantity = BigDecimal("10")
      l.unit_price = BigDecimal("1.50")
      l.country_origin_code = "CN"
      l.value = BigDecimal("2.50")
      l.contract_amount = BigDecimal("2.00")
      l.department = "DEPT"
      l.mid = "MID"

      t = l.commercial_invoice_tariffs.build
      t.hts_code = "1234567890"
      t.classification_qty_1 = BigDecimal("10")
      t.classification_qty_2 = BigDecimal("5")
      t.gross_weight = BigDecimal("100")
      t.spi_primary = "AU"

      i
    }

    it "receives commercial invoices, translates them to internal file objects and sends them" do
      entry = nil
      expect(subject).to receive(:generate_and_send) do |entries|
        expect(entries.length).to eq 1
        entry = entries.first
      end

      subject.generate_and_send_invoices("12345", invoice)

      expect(entry.file_number).to eq "12345"
      expect(entry.customer).to eq "IMP"
      expect(entry.invoices.length).to eq 1

      i = entry.invoices.first
      expect(i.invoice_number).to eq "INV#"
      expect(i.invoice_date).to eq Date.new(2016, 5, 9)
      expect(i.invoice_lines.length).to eq 1

      i = i.invoice_lines.first
      expect(i.po_number).to eq "PO"
      expect(i.part_number).to eq "PART"
      expect(i.pieces).to eq 10
      expect(i.unit_price).to eq 1.50
      expect(i.country_of_origin).to eq "CN"
      expect(i.foreign_value).to eq 2.50
      expect(i.first_sale).to eq 2
      expect(i.department).to eq "DEPT"
      expect(i.mid).to eq "MID"

      expect(i.hts).to eq "1234567890"
      expect(i.quantity_1).to eq 10
      expect(i.quantity_2).to eq 5
      expect(i.gross_weight).to eq 100
      expect(i.spi).to eq "AU"

    end

    it "converts gross weight from grams to KG if instructed" do
      invoice.commercial_invoice_lines.first.commercial_invoice_tariffs.first.gross_weight = 1000
      entry = nil
      expect(subject).to receive(:generate_and_send) do |entries|
        expect(entries.length).to eq 1
        entry = entries.first
      end

      subject.generate_and_send_invoices("12345", invoice, gross_weight_uom: "G")

      expect(entry.invoices.first.invoice_lines.first.gross_weight).to eq 1
    end

    it "converts gross weight from grams to KG, sending 1 KG if converted weight is less than 1 KG" do
      invoice.commercial_invoice_lines.first.commercial_invoice_tariffs.first.gross_weight = 10
      entry = nil
      expect(subject).to receive(:generate_and_send) do |entries|
        expect(entries.length).to eq 1
        entry = entries.first
      end

      subject.generate_and_send_invoices("12345", invoice, gross_weight_uom: "G")

      expect(entry.invoices.first.invoice_lines.first.gross_weight).to eq 1
    end

    it "does not send 1 KG if weight is not converted" do
      invoice.commercial_invoice_lines.first.commercial_invoice_tariffs.first.gross_weight = BigDecimal("0.50")

      entry = nil
      expect(subject).to receive(:generate_and_send) do |entries|
        expect(entries.length).to eq 1
        entry = entries.first
      end

      subject.generate_and_send_invoices("12345", invoice)
      expect(entry.invoices.first.invoice_lines.first.gross_weight).to eq 0
    end
  end

  describe "generate_xls" do
    it "generates an excel workbook" do
      l = entry_data.invoices.first.invoice_lines.first
      l.seller_mid = "SELLER"
      l.buyer_customer_number = "BUYER"

      wb = subject.generate_xls [entry_data]
      expect(wb).not_to be_nil

      sheet = wb.worksheet("CI Load")
      expect(sheet).not_to be_nil

      expect(sheet.row(0)).to eq ["File #", "Customer", "Invoice #", "Invoice Date", "Country of Origin", "Part # / Style", "Pieces", "MID", "Tariff #", "Cotton Fee (Y/N)", "Invoice Foreign Value", "Quantity 1", "Quantity 2", "Gross Weight", "PO #", "Cartons", "First Sale Amount", "NDC / MMV", "Department", "SPI", "Buyer Cust No", "Seller MID"]
      expect(sheet.row(1)).to eq ['597549', 'SALOMON', '15MSA10', '2015-11-01', "PH", "PART", 93.0, "PHMOUINS2106BAT", "4202.92.3031", "N", 3177.86, 93.0, 52.0, 78.0, "5301195481", 10, 218497.20, 20.0, 1.0, "JO", "BUYER", "SELLER"]
      # just make sure the second line has the second part and retains the entry/invoice info
      expect(sheet.row(2)[0..5]).to eq ['597549', 'SALOMON', '15MSA10', '2015-11-01', "PH", "PART2"]
      expect(sheet.row(3)).to eq []
    end
  end
end