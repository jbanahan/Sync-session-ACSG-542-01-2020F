require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmI2ShipmentParser do

  def make_csv_file order_type
    "INV#;;;20160203T0405+0100;;;PO#;6;#{order_type};1234567890;;;CN;25;;;1500.1;400;;987654;;;;;;;;;6990\n" +
    "INV#;;;20160203T0405+0100;;;PO#;7;#{order_type};987654321;;;IN;50;;;2000;500;;REF NO;;;;;;;;;10000"
  end

  let! (:master_setup) {
    stub_master_setup
  }
  let(:hm) { Factory(:importer, system_code: "HENNE") }
  let(:hm_fenix) {Factory(:importer, fenix_customer_number: "887634400RM0001")}
  let(:ca) { Factory(:country, iso_code: "CA")}
  let(:us) { Factory(:country, iso_code: "US")}
  
  let (:cdefs) {
    described_class.new.cdefs
  }
  let (:entry) {
    entry = Factory(:entry, importer: hm, customer_number: "HENNE", source_system: "Alliance", broker_reference: "REF", release_date: Time.zone.now)
    inv = Factory(:commercial_invoice, entry: entry, invoice_number: "987654")
    line = Factory(:commercial_invoice_line, commercial_invoice: inv, part_number: "1234567", mid: "MID", quantity: 10, country_origin_code: "CN")
    tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "9999999999", tariff_description: "Invoice Desc", entered_value: "100")

    entry
  }

  describe "parse" do
    let(:ca_file) { make_csv_file("ZSTO") }
    let(:us_file) { make_csv_file("ZRET") }
    let(:product) { Factory(:product, importer: hm, unique_identifier: "HENNE-1234567", name: "Description") }
    let(:ca_product) { 
      p = product
      c = p.classifications.create! country_id: ca.id
      t = c.tariff_records.create! hts_1: "1234567890"
      p
    }
    let(:us_product) {
      p = product
      c = p.classifications.create! country_id: us.id
      t = c.tariff_records.create! hts_1: "9876543210"
      p 
    }

    before :each do
      hm_fenix
    end
    
    def set_product_custom_values product, product_value, value_order_number, canada_description
      product.update_custom_value! cdefs[:prod_value], product_value
      product.update_custom_value! cdefs[:prod_value_order_number], value_order_number
      if !canada_description.blank?
        classification = product.classifications.find {|c| c.country.iso_code == "CA" }
        classification.update_custom_value!(cdefs[:class_customs_description], canada_description) if classification
      end
      nil
    end

    context "with canadian shipment" do 

      let!(:data_cross_reference) {
        DataCrossReference.add_hm_pars_number "PARS"
      }

      before :each do 
        hm
        # Turn off pars notifications for now
        expect_any_instance_of(described_class).to receive(:pars_threshold).and_return 0
      end

      it "creates an invoice" do
        invoice = nil
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |id|
          invoice = id
        end

        invoice_data = nil
        expect(OpenChain::CustomHandler::Hm::HmParsPdfGenerator).to receive(:generate_pars_pdf) do |data, file|
          invoice_data = data
          # Write something to the file or it won't get sent...since we don't email blank files.
          file << "testing"
          file.flush
        end
        described_class.parse ca_file

        expect(invoice).not_to be_nil
        expect(invoice.invoice_number).to eq "INV#-01"
        expect(invoice.importer).to eq hm_fenix
        expect(invoice.invoice_date).to eq Time.zone.parse("2016-02-03 03:05:00")
        expect(invoice.gross_weight).to eq 4
        expect(invoice.currency).to eq "USD"

        expect(invoice.commercial_invoice_lines.length).to eq 2
        l = invoice.commercial_invoice_lines.first

        expect(l.po_number).to eq "PO#"
        expect(l.part_number).to eq "1234567"
        expect(l.country_origin_code).to eq "CN"
        expect(l.quantity).to eq BigDecimal(25)
        expect(l.unit_price).to eq BigDecimal("999999.99")
        expect(l.customer_reference).to eq "987654"
        expect(l.line_number).to eq 6

        # Always create a tariff line, even if it has no info...it's expected the
        # line will exist pretty much everywhere we deal with invoice lines.
        expect(l.commercial_invoice_tariffs.length).to eq 1
        t = l.commercial_invoice_tariffs.first
        expect(t.gross_weight).to eq 1500

        l = invoice.commercial_invoice_lines.second
        expect(l.po_number).to eq "PO#"
        expect(l.part_number).to eq "9876543"
        expect(l.country_origin_code).to eq "IN"
        expect(l.quantity).to eq BigDecimal(50)
        expect(l.unit_price).to eq BigDecimal("999999.99")
        expect(l.customer_reference).to eq "REF NO"
        expect(l.line_number).to eq 7

        expect(ActionMailer::Base.deliveries.length).to eq 2
        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to eq ["hm_ca@vandegriftinc.com"]
        expect(mail.subject).to eq "H&M Commercial Invoice INV#-01"
        expect(mail.attachments["Invoice INV#-01.xls"]).not_to be_nil
        expect(mail.attachments["INV#-01 Exceptions.xls"]).not_to be_nil

        mail = ActionMailer::Base.deliveries.second
        expect(mail.to).to eq ["HM_Supervisors@Geodis.com", "HM_FieldIT.cl.us@Geodis.com", "ManhattanSupport.cl.us@geodis.com", "OnlineDCPlainfield@hm.com", "Ronald.Colbert@purolator.com", "Terri.Bandy@purolator.com", "Mike.Devitt@purolator.com"]
        expect(mail.cc).to eq ["hm_ca@vandegriftinc.com", "afterhours@vandegriftinc.com"]
        expect(mail.subject).to eq "PARS Coversheet - 2016-02-03.pdf"
        expect(mail.reply_to).to eq ["hm_ca@vandegriftinc.com"]
        expect(mail.body).to include "See attached PDF file for the list of PARS numbers to utilize."
        expect(mail.attachments["PARS Coversheet - 2016-02-03.pdf"]).not_to be_nil

        expect(invoice_data.length).to eq 1
        expect(invoice_data.first.invoice_number).to eq "INV#-01"
        expect(invoice_data.first.pars_number).to eq "PARS"
        expect(invoice_data.first.cartons).to eq 1
        expect(invoice_data.first.weight).to eq 4

        expect(data_cross_reference.reload.value).to eq "1"
      end

      it "prefers the US entry's commercial invoice unit price over the product data" do
        entry
        ca_product
        set_product_custom_values ca_product, BigDecimal("1.5"), "12345", "Description"
        invoice = nil
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |id|
          invoice = id
        end
        described_class.parse ca_file

        expect(invoice).not_to be_nil
        l = invoice.commercial_invoice_lines.first
        expect(l).not_to be_nil
        expect(l.unit_price).to eq BigDecimal("13.00")
        t = l.commercial_invoice_tariffs.first
        expect(t).not_to be_nil
        expect(t.hts_code).to eq "1234567890"
        expect(t.tariff_description).to eq "Description"
      end

      it "uses product data if invoice is not present" do
        invoice = nil
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |id|
          invoice = id
        end
        ca_product
        set_product_custom_values ca_product, BigDecimal("1.5"), "12345", "Description"
        described_class.parse ca_file

        expect(invoice).not_to be_nil

        l = invoice.commercial_invoice_lines.first
        # 1.95 is unit price times the multiplier
        expect(l.unit_price).to eq BigDecimal("1.95")
        t = l.commercial_invoice_tariffs.first
        expect(t).not_to be_nil
        expect(t.hts_code).to eq "1234567890"
        expect(t.tariff_description).to eq "Description"
      end

      it "does not use hts code from invoice line if product data is missing" do
        entry
        ca_product
        set_product_custom_values ca_product, BigDecimal("1.5"), "12345", "Description"
        ca_product.classifications.first.tariff_records.first.update_attributes! hts_1: ""

        invoice = nil
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |id|
          invoice = id
        end
        described_class.parse ca_file

        expect(invoice).not_to be_nil
        l = invoice.commercial_invoice_lines.first
        expect(l).not_to be_nil
        expect(l.unit_price).to eq BigDecimal("13.00")
        t = l.commercial_invoice_tariffs.first
        expect(t).not_to be_nil
        expect(t.hts_code).to be_blank
        expect(t.tariff_description).to eq "Description"
      end

      it "splits the source file into multiple files and processes each individually" do
        split_file = CSV.parse(ca_file, col_sep: ";")
        expect_any_instance_of(described_class).to receive(:split_file).and_return [[split_file[0]], [split_file[1]]]

        invoices = []
        allow(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |inv|
          invoices << inv
        end

        described_class.parse ca_file

        expect(invoices.length).to eq 2
        # Just validate that the invoice numbers match what we expect...then we'll validate the number of files that go out.
        expect(invoices.first.invoice_number).to eq "INV#-01"
        expect(invoices.first.commercial_invoice_lines.first.part_number).to eq "1234567"
        
        # Make sure the 
        expect(invoices.second.invoice_number).to eq "INV#-02"
        expect(invoices.second.commercial_invoice_lines.first.part_number).to eq "9876543"

        expect(ActionMailer::Base.deliveries.length).to eq 3
        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to eq ["hm_ca@vandegriftinc.com"]
        expect(mail.subject).to eq "H&M Commercial Invoice INV#-01"
        expect(mail.attachments["Invoice INV#-01.xls"]).not_to be_nil
        expect(mail.attachments["INV#-01 Exceptions.xls"]).not_to be_nil

        mail = ActionMailer::Base.deliveries.second
        expect(mail.to).to eq ["hm_ca@vandegriftinc.com"]
        expect(mail.subject).to eq "H&M Commercial Invoice INV#-02"
        expect(mail.attachments["Invoice INV#-02.xls"]).not_to be_nil
        expect(mail.attachments["INV#-02 Exceptions.xls"]).not_to be_nil
      end

      it "sends email regarding PARS numbers being needed" do
        p = described_class.new

        allow(p).to receive(:pars_threshold).and_return 30
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate)
        p.parse ca_file

        expect(ActionMailer::Base.deliveries.length).to eq 3
        mail = ActionMailer::Base.deliveries.last

        expect(mail.to).to eq ["terri.bandy@purolator.com", "mdevitt@purolator.com", "Jessica.Webber@purolator.com"]
        expect(mail.cc).to eq ["hm_ca@vandegriftinc.com", "hm_support@vandegriftinc.com"]
        expect(mail.reply_to).to eq ["hm_support@vandegriftinc.com"]
        expect(mail.subject).to eq "More PARS Numbers Required"
        expect(mail.body).to include "0 PARS numbers are remaining to be used for H&amp;M border crossings.  Please supply more to Vandegrift to ensure future crossings are not delayed."
      end

      it "handles invalid invoice date" do
        file = ca_file.gsub("20160203T0405+0100", "T")

        invoice = nil
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |id|
          invoice = id
        end
        described_class.parse file

        expect(invoice).not_to be_nil
        expect(invoice.invoice_date).to eq ActiveSupport::TimeZone["America/New_York"].parse "1900-01-01 00:00"
      end
    end

    context "with us shipment" do

      before :each do 
        hm
        # The actual invoice produced by US and CA files are identical except wrt to hts handling
        us_product
        ca_product
      end

      def set_us_product_custom_values product_value, value_order_number
        set_product_custom_values us_product, product_value, value_order_number, nil
      end

      it "creates an invoice using entry information and product data" do
        entry
        set_us_product_custom_values 10.00, "987654"
        invoice = nil
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator).to receive(:generate_and_send_invoices) do |instance, file_number, inv|
          expect(file_number).to eq "INV#"
          invoice = inv
        end

        described_class.parse us_file
        expect(invoice).not_to be_nil

        expect(invoice.commercial_invoice_lines.length).to eq 2
        line = invoice.commercial_invoice_lines.first
        expect(line.commercial_invoice_tariffs.length).to eq 1
        expect(line.mid).to eq "MID"
        # Value equals 13 because of the 30% value multiplier applied to the 10 value above
        expect(line.unit_price).to eq 13
        expect(line.value).to eq 325

        tar = line.commercial_invoice_tariffs.first
        expect(tar.hts_code).to eq "9876543210"
        expect(tar.tariff_description).to eq "Invoice Desc"
      end

      it "falls back to matching without part number if US entry's invoice doesn't have one" do
        line = entry.commercial_invoices.first.commercial_invoice_lines.first
        line.update_attributes! part_number: ""

        set_us_product_custom_values 10.00, "987654"
        invoice = nil
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator).to receive(:generate_and_send_invoices) do |instance, file_number, inv|
          expect(file_number).to eq "INV#"
          invoice = inv
        end

        described_class.parse us_file
        expect(invoice).not_to be_nil

        expect(invoice.commercial_invoice_lines.length).to eq 2
        line = invoice.commercial_invoice_lines.first
        expect(line.commercial_invoice_tariffs.length).to eq 1
        expect(line.mid).to eq "MID"
        # Value equals 13 because of the 30% value multiplier applied to the 10 value above
        expect(line.unit_price).to eq 13
        expect(line.value).to eq 325

        tar = line.commercial_invoice_tariffs.first
        expect(tar.hts_code).to eq "9876543210"
        expect(tar.tariff_description).to eq "Invoice Desc"
      end

      it "fails to match to US entry without part number if invoice has multiple lines" do
        invoice = entry.commercial_invoices.first
        invoice.commercial_invoice_lines.first.update_attributes! part_number: ""
        invoice.commercial_invoice_lines.create! mid: "MID", quantity: 10, country_origin_code: "CN"
        
        set_us_product_custom_values 20, "987654"
        product.classifications.first.update_custom_value!(cdefs[:class_customs_description], "US Description")
        
        invoice = nil
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator).to receive(:generate_and_send_invoices) do |instance, file_number, inv|
          expect(file_number).to eq "INV#"
          invoice = inv
        end

        described_class.parse us_file
        expect(invoice).not_to be_nil

        expect(invoice.commercial_invoice_lines.length).to eq 2
        line = invoice.commercial_invoice_lines.first
        expect(line.commercial_invoice_tariffs.length).to eq 1
        expect(line.mid).to be_blank
        # Value equals 13 because of the 30% value multiplier applied to the 10 value above
        expect(line.unit_price).to eq 26
        expect(line.value).to eq 650

        tar = line.commercial_invoice_tariffs.first
        expect(tar.hts_code).to eq "9876543210"
        expect(tar.tariff_description).to eq "US Description"

        # If there was no entry match, an exception report should have been generated (since MID will be blank)
        email = ActionMailer::Base.deliveries.first
        expect(email).not_to be_nil
        expect(email.subject).to eq "[VFI Track] H&M Returns Shipment # INV#"

        email = ActionMailer::Base.deliveries.second
        expect(email).not_to be_nil
        expect(email.subject).to eq "[VFI Track] H&M Commercial Invoice INV# Exceptions"
      end

      it "falls back to product data if entry isn't present" do
        set_us_product_custom_values 20, "987654"
        product.classifications.first.update_custom_value!(cdefs[:class_customs_description], "US Description")
        invoice = nil
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator).to receive(:generate_and_send_invoices) do |instance, file_number, inv|
          expect(file_number).to eq "INV#"
          invoice = inv
        end

        described_class.parse us_file
        expect(invoice).not_to be_nil

        expect(invoice.commercial_invoice_lines.length).to eq 2
        line = invoice.commercial_invoice_lines.first
        expect(line.commercial_invoice_tariffs.length).to eq 1
        expect(line.mid).to be_nil
        # Value equals 263 because of the 30% value multiplier applied to the 10 value above
        expect(line.unit_price).to eq 26
        expect(line.value).to eq 650

        tar = line.commercial_invoice_tariffs.first
        expect(tar.hts_code).to eq "9876543210"
        expect(tar.tariff_description).to eq "US Description"
      end

      it "sends shipping docs" do
        described_class.parse us_file

        email = ActionMailer::Base.deliveries.first
        expect(email).not_to be_nil

        expect(email.to).to eq ["Brampton-H&M.cl.us@geodis.com", "OnlineDCPlainfield@hm.com"]
        expect(email.bcc).to eq ["nb@vandegriftinc.com"]
        expect(email.reply_to).to eq ["nb@vandegriftinc.com"]
        expect(email.subject).to eq "[VFI Track] H&M Returns Shipment # INV#"
        expect(email.body.raw_source).to include "The Commercial Invoice printout and addendum for invoice # INV# is attached to this email."
        expect(email.attachments["Invoice INV#.pdf"]).not_to be_nil
        expect(email.attachments["Invoice Addendum INV#.xls"]).not_to be_nil
      end

      it "translates MM country code to BU" do
        file = us_file.gsub(";CN;", ";MM;")

        entry
        set_us_product_custom_values 10.00, "987654"

        invoice = nil
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator).to receive(:generate_and_send_invoices) do |instance, file_number, inv|
          invoice = inv
        end
        described_class.parse file

        expect(invoice).not_to be_nil
        expect(invoice.commercial_invoice_lines.first.country_origin_code).to eq "BU"
      end
    end

    it "raises an error if HM record is not present" do
      expect {described_class.parse us_file}.to raise_error "No importer record found with system code HENNE."
    end
  end

  describe "make_pdf_info" do
    let (:invoice) {
      i = CommercialInvoice.new
      i.invoice_number = "INV"
      i.importer = Company.new(name: "Company")
      i.gross_weight = BigDecimal("650")
      i.invoice_date = Date.new(2016, 7, 8)

      line = CommercialInvoiceLine.new 
      line.quantity = BigDecimal("10")
      line.value = BigDecimal("100.40")

      i.commercial_invoice_lines << line

      line = CommercialInvoiceLine.new 
      line.quantity = BigDecimal("10.1")
      line.value = BigDecimal("100.407")
      i.commercial_invoice_lines << line

      i
    }

    it "generates pdf data from HM commercial invoice" do
      row = []
      row[14] = 'Carrier'
      row[16] = 350

      i = subject.make_pdf_info invoice, [row, row]

      expect(i.control_number).to eq "INV"
      expect(i.exporter_reference).to eq "INV"
      expect(i.export_date).to eq Date.new(2016, 7, 8)
      expect(i.terms).to eq "FOB Windsor Ontario"
      expect(i.origin).to eq "Ontario"
      expect(i.destination).to eq "Indiana"
      expect(i.local_carrier).to eq "Carrier"
      expect(i.export_carrier).to eq "Carrier"
      expect(i.port_of_entry).to eq "Detroit, MI"
      expect(i.lading_location).to eq "Ontario"
      expect(i.related).to be_falsy
      expect(i.duty_for).to eq "Consignee"
      expect(i.date_of_sale).to eq Date.new(2016, 7, 8)
      expect(i.total_packages).to eq "20 Packages"
      expect(i.total_gross_weight).to eq "0.7 KG"
      expect(i.description_of_goods).to eq "For Customs Clearance by: Vandegrift\nFor the account of: H & M HENNES & MAURITZ L.P.\nMail order goods being returned by the Canadian\nConsumer for credit or exchange."
      expect(i.export_reason).to eq "Not Sold"
      expect(i.mode_of_transport).to eq "Road"
      expect(i.containerized).to be_falsy
      expect(i.owner_agent).to eq "Agent"
      expect(i.invoice_total).to eq "$200.81"

      a = i.exporter_address
      expect(a.name).to eq "OHL"
      expect(a.line_1).to eq "300 Kennedy Rd S Unit B"
      expect(a.line_2).to eq "Brampton, ON, L6W 4V2"
      expect(a.line_3).to eq "Canada"

      a = i.consignee_address
      expect(a.name).to eq "H&M Hennes & Mauritz"
      expect(a.line_1).to eq "1600 River Road, Building 1"
      expect(a.line_2).to eq "Burlington Township, NJ 08016"
      expect(a.line_3).to eq "(609) 239-8703"

      a = i.firm_address
      expect(a.name).to eq "OHL"
      expect(a.line_1).to eq "281 AirTech Pkwy. Suite 191"
      expect(a.line_2).to eq "Plainfield, IN 46168"
      expect(a.line_3).to eq "USA"

      expect(i.employee).to eq "Shahzad Dad"
    end
  end

  describe "build_addendum_spreadsheet" do
    let (:invoice) {
      i = CommercialInvoice.new
      i.invoice_number = "INV"
      i.importer = Company.new(name: "Company")
      i.gross_weight = BigDecimal("650")
      i.invoice_date = Date.new(2016, 7, 8)

      line = CommercialInvoiceLine.new 
      line.quantity = BigDecimal("10")
      line.value = BigDecimal("100.40")
      line.part_number = "12345"
      line.mid = "MID"
      line.country_origin_code = "COO"
      line.unit_price = 20.50
      t = line.commercial_invoice_tariffs.build
      t.tariff_description = "DESC"
      t.hts_code = "1234567890"

      i.commercial_invoice_lines << line

      line = CommercialInvoiceLine.new 
      line.quantity = BigDecimal("10.1")
      line.value = BigDecimal("200.40")
      line.part_number = "123456"
      line.mid = "MID2"
      line.country_origin_code = "COO2"
      line.unit_price = 21.50
      t = line.commercial_invoice_tariffs.build
      t.tariff_description = "DESC2"
      t.hts_code = "9876543210"

      i.commercial_invoice_lines << line

      i
    }

    it "builds the spreadsheet using invoice data and csv data" do
      row = []
      row[16] = 800
      wb = subject.build_addendum_spreadsheet invoice, [row, row]

      expect(wb.worksheets.length).to eq 1
      sheet = wb.worksheets.first

      expect(sheet.row(0)).to eq ["Shipment ID", "Part Number", "Description", "MID", "Country of Origin", "HTS", "Net Weight", "Net Weight UOM", "Unit Price", "Quantity", "Total Value"]
      expect(sheet.row(1)).to eq ["INV", "12345", "DESC", "MID", "COO", "1234.56.7890", 800, "G", 20.50, 10, 100.40]
      expect(sheet.row(2)).to eq ["INV", "123456", "DESC2", "MID2", "COO2", "9876.54.3210", 800, "G", 21.50, 10.1, 200.40]
      expect(sheet.row(3)).to eq ["", "", "", "", "", "", 1600, "", "", 20.1, 300.80]
    end
  end

  describe "build_missing_product_spreadsheet" do
    let(:ca_product) { 
      p = Factory(:product, importer: hm, unique_identifier: "HENNE-CA-Product", name: "CA Description")
      c = p.classifications.create! country_id: ca.id
      t = c.tariff_records.create! hts_1: "1234567890"
      # This is the PO number/Invoice number to use for the entry lookup (make sure the code handles splitting multiple out)
      p.update_custom_value! cdefs[:prod_po_numbers], "987654\n Another PO"
      p
    }
    let(:us_product) {
      p = Factory(:product, importer: hm, unique_identifier: "HENNE-US-Product", name: "US Description")
      c = p.classifications.create! country_id: us.id
      t = c.tariff_records.create! hts_1: "9876543210"
      p 
    }

    context "with fenix data" do
      it "reports on products missing classifications" do
        missing_products = [{product: ca_product, part_number: "12345", order_number: "23456", country_origin: "BD"}, {product: us_product, part_number: "9876", order_number: "345678", country_origin: "IN"}, {product: nil}]
        entry

        wb = subject.build_missing_product_spreadsheet "INV", missing_products, :fenix

        expect(wb.worksheets.length).to eq 1
        expect(wb.worksheets.first.name).to eq "INV Exceptions"
        sheet = wb.worksheets.first

        expect(sheet.row(0)).to eq ["Part Number", "H&M Order #", "H&M Country Origin", "H&M Description", "PO Numbers", "US HS Code", "CA HS Code", "Product Value", "MID", "Product Link", "US Entry Links", "Resolution"]
        expect(sheet.row(1)).to eq ["12345", "23456", "BD", "CA Description", "987654, Another PO", "", "1234.56.7890", "", "", XlsMaker.create_link_cell(ca_product.excel_url, "12345"), XlsMaker.create_link_cell(entry.excel_url, "REF"), "Use Part Number and H&M Order # (Invoice Number in US Entry) to lookup the missing information in the linked US Entry then add the Canadian classification in linked Product record."]
        expect(sheet.row(2)).to eq ["9876", "345678", "IN", "US Description", "", "9876.54.3210", "", "","", XlsMaker.create_link_cell(us_product.excel_url, "9876"), "", "Use linked Product and add Canadian classifiction in VFI Track."]
      end

      it "reports missing product value if classifications are present" do
        cl = ca_product.classifications.create! country_id: us.id
        t = cl.tariff_records.create! hts_1: "1234567890"

        missing_products = [{product: ca_product, part_number: "12345", order_number: "23456", country_origin: "BD", product_value: BigDecimal("999999.99"), mid: "MID"}]
        entry

        wb = subject.build_missing_product_spreadsheet "INV", missing_products, :fenix

        expect(wb.worksheets.length).to eq 1
        expect(wb.worksheets.first.name).to eq "INV Exceptions"
        sheet = wb.worksheets.first

        expect(sheet.row(0)).to eq ["Part Number", "H&M Order #", "H&M Country Origin", "H&M Description", "PO Numbers", "US HS Code", "CA HS Code", "Product Value", "MID", "Product Link", "US Entry Links", "Resolution"]
        expect(sheet.row(1)).to eq ["12345", "23456", "BD", "CA Description", "987654, Another PO", "1234.56.7890", "1234.56.7890", 999999.99, "MID", XlsMaker.create_link_cell(ca_product.excel_url, "12345"), XlsMaker.create_link_cell(entry.excel_url, "REF"), "The Product Value field must be filled in on the linked Product using information from any US Entries the product appears on."]
      end
    end

    context "with kewill data" do
      it "reports on products missing classifications" do
        missing_products = [{product: us_product, part_number: "9876", order_number: "345678", country_origin: "IN", product_value: BigDecimal("1"), mid: "MID"}]
        entry

        wb = subject.build_missing_product_spreadsheet "INV", missing_products, :kewill

        expect(wb.worksheets.length).to eq 1
        expect(wb.worksheets.first.name).to eq "INV Exceptions"
        sheet = wb.worksheets.first

        expect(sheet.row(0)).to eq ["Part Number", "H&M Order #", "H&M Country Origin", "H&M Description", "PO Numbers", "US HS Code", "CA HS Code", "Product Value", "MID", "Product Link", "US Entry Links", "Resolution"]
        expect(sheet.row(1)).to eq ["9876", "345678", "IN", "US Description", "", "9876.54.3210", "", 1, "MID", XlsMaker.create_link_cell(us_product.excel_url, "9876"), "", "Use Part Number and the H&M Order # (Invoice Number in US Entry) to lookup the missing information from the source US Entry."]
      end
    end
  end

  describe "split_file" do
    it "splits a 'file' at 999 rows for fenix" do
      file_rows = []
      # column 6 is the PO number which we can't split across, so we'll make it unique.
      (1..1000).each { |x| file_rows << ["ship", nil, nil, nil, nil, nil, x] }

      files = subject.split_file(:fenix, file_rows)
      expect(files.length).to eq 2
      expect(files.first.length).to eq 999
      expect(files.first.first[6]).to eq 1
      expect(files.first.last[6]).to eq 999

      expect(files.second.first[6]).to eq 1000
      expect(files.second.last[6]).to eq 1000
      expect(files.second.length).to eq 1
    end

    it "doesn't split anything for kewill" do
      file = []
      (1..1000).each { |x| file << [x] }

      files = subject.split_file(:kewill, file)

      expect(files.length).to eq 1
      expect(files.first.length).to eq 1000
    end

    it "splits a file to prevent a PO number from getting split across multiple files" do
      file_rows = [
        ["ship", nil, nil, nil, nil, nil, "PO1"],
        ["ship", nil, nil, nil, nil, nil, "PO2"],
        ["ship", nil, nil, nil, nil, nil, "PO2"]
      ]

      expect(subject).to receive(:max_fenix_invoice_length).at_least(:once).and_return 2

      files = subject.split_file(:fenix, file_rows)

      expect(files.length).to eq 2
      expect(files.first.length).to eq 1
      expect(files.first.first[6]).to eq "PO1"

      expect(files.second.length).to eq 2
      expect(files.second.first[6]).to eq "PO2"
      expect(files.second.last[6]).to eq "PO2"
    end

    it "doesn't split a file that doesn't need splitting" do
      file_rows = [
        ["ship", nil, nil, nil, nil, nil, "PO1"],
        ["ship", nil, nil, nil, nil, nil, "PO2"],
        ["ship", nil, nil, nil, nil, nil, "PO2"]
      ]

      expect(subject).to receive(:max_fenix_invoice_length).at_least(:once).and_return 3

      files = subject.split_file(:fenix, file_rows)

      expect(files.length).to eq 1
      expect(files.first.length).to eq 3
      expect(files.first[0][6]).to eq "PO1"
      expect(files.first[1][6]).to eq "PO2"
      expect(files.first[2][6]).to eq "PO2"
    end

    it "starts a new file when shipment number changes (regardless of what the PO is)" do
      file_rows = [
        ["ship1", nil, nil, nil, nil, nil, "PO1"],
        ["ship2", nil, nil, nil, nil, nil, "PO2"],
        ["ship3", nil, nil, nil, nil, nil, "PO2"]
      ]

      expect(subject).to receive(:max_fenix_invoice_length).at_least(:once).and_return 3

      files = subject.split_file(:fenix, file_rows)

      expect(files.length).to eq 3
      expect(files[0].length).to eq 1
      expect(files[0][0][0]).to eq "ship1"
      expect(files[1][0][0]).to eq "ship2"
      expect(files[2][0][0]).to eq "ship3"
    end
  end
end
