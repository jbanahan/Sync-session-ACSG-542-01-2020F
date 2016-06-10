require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmI2ShimentParser do

  def make_csv_file order_type
    "INV#;;;20160203T0405+0100;;;PO#;6;#{order_type};PART #;;;CN;25;;;;100;;REF NO;;;;;;;;;6990\n" +
    "INV#;;;20160203T0405+0100;;;PO#;7;#{order_type};PART 2;;;IN;50;;;;200;;REF NO;;;;;;;;;10000"
  end

  describe "parse" do
    let(:ca_file) { make_csv_file("ZSTO") }
    let(:us_file) { make_csv_file("ZRET") }
    let(:hm) { Factory(:importer, system_code: "HENNE") }
    let(:ca) { Factory(:country, iso_code: "CA")}
    let(:us) { Factory(:country, iso_code: "US")}
    let(:product) { Factory(:product, importer: hm, unique_identifier: "HENNE-PART #", name: "Description") }
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

    context "with canadian shipment" do

      before :each do 
        hm
      end

      it "creates an invoice" do
        invoice = nil
        OpenChain::CustomHandler::FenixNdInvoiceGenerator.should_receive(:generate) do |id|
          invoice = id
        end
        described_class.parse ca_file

        expect(invoice).not_to be_nil
        expect(invoice.invoice_number).to eq "INV#"
        expect(invoice.importer).to eq hm
        expect(invoice.invoice_date).to eq Time.zone.parse("2016-02-03 03:05:00")
        expect(invoice.gross_weight).to eq 300

        expect(invoice.commercial_invoice_lines.length).to eq 2
        l = invoice.commercial_invoice_lines.first

        expect(l.po_number).to eq "PO#"
        expect(l.part_number).to eq "PART #"
        expect(l.country_origin_code).to eq "CN"
        expect(l.quantity).to eq BigDecimal(25)
        expect(l.unit_price).to eq BigDecimal("69.90")
        expect(l.customer_reference).to eq "REF NO"
        expect(l.line_number).to eq 6

        # Always create a tariff line, even if it has no info...it's expected the
        # line will exist pretty much everywhere we deal with invoice lines.
        expect(l.commercial_invoice_tariffs.length).to eq 1

        l = invoice.commercial_invoice_lines.second
        expect(l.po_number).to eq "PO#"
        expect(l.part_number).to eq "PART 2"
        expect(l.country_origin_code).to eq "IN"
        expect(l.quantity).to eq BigDecimal(50)
        expect(l.unit_price).to eq BigDecimal("100")
        expect(l.customer_reference).to eq "REF NO"
        expect(l.line_number).to eq 7
      end

      it "finds tariff associated with part number and uses it" do
        invoice = nil
        OpenChain::CustomHandler::FenixNdInvoiceGenerator.should_receive(:generate) do |id|
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
        OpenChain::CustomHandler::FenixNdInvoiceGenerator.should_receive(:generate) do |id|
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
      end

      it "creates an invoice using product US classification" do
        # The actual invoice produced by US and CA files are identical except wrt to hts handling
        us_product

        invoice = nil
        OpenChain::CustomHandler::KewillCommercialInvoiceGenerator.any_instance.should_receive(:generate_and_send_invoices) do |file_number, inv|
          expect(file_number).to be_nil
          invoice = inv
        end

        described_class.parse us_file
        expect(invoice).not_to be_nil

        expect(invoice.commercial_invoice_lines.length).to eq 2
        line = invoice.commercial_invoice_lines.first
        expect(line.commercial_invoice_tariffs.length).to eq 1

        tar = line.commercial_invoice_tariffs.first
        expect(tar.hts_code).to eq "9876543210"
      end
    end

    it "raises an error if HM record is not present" do
      expect {described_class.parse us_file}.to raise_error "No importer record found with system code HENNE."
    end
  end

end