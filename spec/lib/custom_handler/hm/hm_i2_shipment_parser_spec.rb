require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmI2ShipmentParser do

  def make_csv_file order_type
    "INV#;;;20160203T0405+0100;;;PO#;6;#{order_type};1234567890;;;CN;25;;;1500.1;400;;REF NO;;;;;;;;;6990\n" +
    "INV#;;;20160203T0405+0100;;;PO#;7;#{order_type};987654321;;;IN;50;;;2000;500;;REF NO;;;;;;;;;10000"
  end

  describe "parse" do
    let(:ca_file) { make_csv_file("ZSTO") }
    let(:us_file) { make_csv_file("ZRET") }
    let(:hm) { Factory(:importer, system_code: "HENNE") }
    let!(:hm_fenix) {Factory(:importer, fenix_customer_number: "887634400RM0001")}
    let(:ca) { Factory(:country, iso_code: "CA")}
    let(:us) { Factory(:country, iso_code: "US")}
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
    let (:cdefs) {
      subject.instance_variable_get(:@cdefs)
    }
    let (:entry) {
      entry = Factory(:entry, importer: hm, customer_number: "HENNE")
      inv = Factory(:commercial_invoice, entry: entry, invoice_number: "987654")
      line = Factory(:commercial_invoice_line, commercial_invoice: inv, part_number: "1234567", mid: "MID")
    }

    context "with canadian shipment" do

      before :each do 
        hm
      end

      it "creates an invoice" do
        invoice = nil
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |id|
          invoice = id
        end
        described_class.parse ca_file

        expect(invoice).not_to be_nil
        expect(invoice.invoice_number).to eq "INV#"
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
        expect(l.unit_price).to be_nil
        expect(l.customer_reference).to eq "REF NO"
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
        expect(l.unit_price).to be_nil
        expect(l.customer_reference).to eq "REF NO"
        expect(l.line_number).to eq 7
      end

      it "finds tariff associated with part number and uses it" do
        invoice = nil
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |id|
          invoice = id
        end
        ca_product
        described_class.parse ca_file

        expect(invoice).not_to be_nil

        l = invoice.commercial_invoice_lines.first
        t = l.commercial_invoice_tariffs.first
        expect(t).not_to be_nil
        expect(t.hts_code).to eq "1234567890"
        expect(t.tariff_description).to be_blank
      end

      it "uses customs description from product" do
        invoice = nil
        expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate) do |id|
          invoice = id
        end
        ca_product.classifications.first.update_custom_value! cdefs[:class_customs_description], "Description"
        described_class.parse ca_file
        expect(invoice).not_to be_nil

        l = invoice.commercial_invoice_lines.first
        t = l.commercial_invoice_tariffs.first
        expect(t).not_to be_nil
        expect(t.tariff_description).to eq "Description"
      end
    end

    context "with us shipment" do

      before :each do 
        hm
        # The actual invoice produced by US and CA files are identical except wrt to hts handling
        us_product
        ca_product
      end

      def set_product_custom_values product_value, value_order_number, canada_description
        cdefs = subject.instance_variable_get(:@cdefs)
        us_product.update_custom_value! cdefs[:prod_value], product_value
        us_product.update_custom_value! cdefs[:prod_value_order_number], value_order_number
        if !canada_description.blank?
          classification = us_product.classifications.find {|c| c.country.iso_code == "CA" }
          classification.update_custom_value!(cdefs[:class_customs_description], canada_description) if classification
        end
        nil
      end

      it "creates an invoice using product US classification and entry information" do
        entry
        set_product_custom_values 10.00, "987654", "Canada Desc"
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
        # Value equals 3 because of the 30% value multiplier applied to the 10 value above
        expect(line.unit_price).to eq 13
        expect(line.value).to eq 325

        tar = line.commercial_invoice_tariffs.first
        expect(tar.hts_code).to eq "9876543210"
        expect(tar.tariff_description).to eq "Canada Desc"
      end

      it "sends shipping docs" do
        described_class.parse us_file

        email = ActionMailer::Base.deliveries.first
        expect(email).not_to be_nil

        expect(email.to).to eq ["Brampton-H&M@ohl.com", "OnlineDCPlainfield@hm.com"]
        expect(email.bcc).to eq ["nb@vandegriftinc.com"]
        expect(email.reply_to).to eq ["nb@vandegriftinc.com"]
        expect(email.subject).to eq "[VFI Track] H&M Returns Shipment # INV#"
        expect(email.body.raw_source).to include "The Commercial Invoice printout and addendum for invoice # INV# is attached to this email."
        expect(email.attachments["Invoice INV#.pdf"]).not_to be_nil
        expect(email.attachments["Invoice Addendum INV#.xls"]).not_to be_nil
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
end