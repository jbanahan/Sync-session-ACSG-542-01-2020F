require 'spec_helper'

describe OpenChain::CustomHandler::Burlington::BurlingtonShipmentCiLoadGenerator do

  let (:cdefs) {
    subject.cdefs
  }

  let (:us) { Factory(:country, iso_code: "US")}

  let (:burlington) { Factory(:importer, system_code: "BURLI")}

  let (:product) {
    product = Factory(:product)
    product.update_custom_value! cdefs[:prod_part_number], "PARTNO"
    c = product.classifications.create! country: us
    c.tariff_records.create! hts_1: "1234567890"
    product
  }

  let (:order) {
    order = Factory(:order, customer_order_number: "PO")
    order_line = Factory(:order_line, order: order, price_per_unit: BigDecimal("12.99"), product: product)

    order.reload
  }

  let (:shipment) {
    shipment = Factory(:shipment, importer: burlington, importer_reference: "ImpRef", master_bill_of_lading: "MASTERBILL", last_exported_from_source: "2017-02-01 00:00")
    shipment_line = Factory(:shipment_line, shipment: shipment, product: product, carton_qty: 10, gross_kgs: BigDecimal("100.50"), quantity: 99, linked_order_line_id: order.order_lines.first.id)
    shipment_line_2 = Factory(:shipment_line, shipment: shipment, product: product, carton_qty: 20, gross_kgs: BigDecimal("100.50"), quantity: 198, linked_order_line_id: order.order_lines.first.id)

    shipment.reload
  }

  describe "generate_entry_data" do

    it "turns shipment data into CI Load struct objects" do
      ci_load = subject.generate_entry_data shipment
      expect(ci_load).not_to be_nil

      expect(ci_load.customer).to eq "BURLI"
      expect(ci_load.file_number).to eq "MASTERBILL"
      expect(ci_load.invoices.length).to eq 1

      expect(ci_load.invoices.length).to eq 1
      invoice = ci_load.invoices.first
      expect(invoice.invoice_number).to eq "ImpRef"

      expect(invoice.invoice_lines.length).to eq 1
      line = ci_load.invoices.first.invoice_lines.first

      expect(line.part_number).to eq "PARTNO"
      expect(line.cartons).to eq 30
      expect(line.gross_weight).to eq BigDecimal("201")
      expect(line.pieces).to eq 297
      expect(line.buyer_customer_number).to eq "BURLI"
      expect(line.po_number).to eq "PO"
      expect(line.unit_price).to eq BigDecimal("12.99")
      expect(line.foreign_value).to eq BigDecimal("3858.03")
      expect(line.hts).to eq "1234567890"
    end

    it "skips lines missing orders" do
      shipment.shipment_lines.second.piece_sets.destroy_all

      ci_load = subject.generate_entry_data shipment
      expect(ci_load.invoices.length).to eq 1

      expect(ci_load.invoices.first.invoice_lines.try(:length)).to eq 1
      line = ci_load.invoices.first.invoice_lines.first

      expect(line.part_number).to eq "PARTNO"
      expect(line.cartons).to eq 10
      expect(line.gross_weight).to eq BigDecimal("100.50")
      expect(line.pieces).to eq 99
      expect(line.buyer_customer_number).to eq "BURLI"
    end

    it "handles multiple shipments, making each one a new invoice" do
      shipment2 = Factory(:shipment, importer_reference: "Ref2", master_bill_of_lading: "MASTERBILL")
      shipment_line_2 = Factory(:shipment_line, shipment: shipment2, product: product, carton_qty: 1, gross_kgs: BigDecimal("10"), quantity: 10, linked_order_line_id: order.order_lines.first.id)

      shipment2.reload

      ci_load = subject.generate_entry_data [shipment, shipment2]
      expect(ci_load.invoices.length).to eq 2
      inv = ci_load.invoices.first
      expect(inv.invoice_number).to eq "ImpRef"
      expect(inv.invoice_lines.length).to eq 1

      inv = ci_load.invoices.second
      expect(inv.invoice_number).to eq "Ref2"
      expect(inv.invoice_lines.length).to eq 1

      line = inv.invoice_lines.first
      expect(line.part_number).to eq "PARTNO"
      expect(line.cartons).to eq 1
      expect(line.gross_weight).to eq BigDecimal("10")
      expect(line.pieces).to eq 10
      expect(line.buyer_customer_number).to eq "BURLI"
    end

  end

  describe "generate_and_send" do

    let (:generator) {
      instance_double(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator)
    }

    let (:workbook) {
      double("workbook")
    }

    it "generates data and sends it to the kewill generator" do
      expect(generator).to receive(:generate_xls).with(instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry)).and_return workbook

      expect(subject).to receive(:kewill_generator).and_return generator
      expect(subject).to receive(:send_xls_to_google_drive).with(workbook, "MASTERBILL.xls")
      subject.generate_and_send [shipment]
    end

    it "finds shipments already sent with same master bill and resends them" do
      shipment2 = Factory(:shipment, importer: shipment.importer, importer_reference: "ARef2", master_bill_of_lading: shipment.master_bill_of_lading)
      shipment_line_2 = Factory(:shipment_line, shipment: shipment2, product: product, carton_qty: 1, gross_kgs: BigDecimal("10"), quantity: 10, linked_order_line_id: order.order_lines.first.id)
      shipment.sync_records.create! trading_partner: "CI Load", sent_at: Time.zone.now

      expect(subject).to receive(:kewill_generator).and_return generator
      expect(subject).to receive(:send_xls_to_google_drive).with(workbook, "MASTERBILL.xls")
      ci_load = nil
      expect(generator).to receive(:generate_xls) do |cil|
        ci_load = cil
        workbook
      end

      subject.generate_and_send [shipment]

      expect(ci_load).not_to be_nil
      expect(ci_load.invoices.length).to eq 2
      expect(ci_load.invoices.first.invoice_number).to eq shipment2.importer_reference
      expect(ci_load.invoices.second.invoice_number).to eq shipment.importer_reference
    end
  end

  describe "send_xls_to_google_drive" do
    let (:wb) {
      wb, sheet = XlsMaker.create_workbook_and_sheet "sheet", ["header"]
      wb
    }

    it "passes tempfile of given spreadsheet object to drive class" do
      received_spreadsheet = nil
      expect(OpenChain::GoogleDrive).to receive(:upload_file) do |account, path, file|
        expect(account).to eq "integration@vandegriftinc.com"
        expect(path).to eq "Burlington CI Load/file.xls"
        received_spreadsheet = Spreadsheet.open file.path
      end

      subject.send_xls_to_google_drive wb, "file.xls"

      expect(received_spreadsheet).not_to be_nil
      expect(received_spreadsheet.worksheet("sheet")).not_to be_nil
    end
  end


  describe "find_generate_and_send" do

    before :each do
      shipment
    end

    it "finds available shipments and sends them" do
      sent = []
      expect(subject).to receive(:generate_and_send) do |shipments|
        sent << shipments

        shipments
      end

      now = ActiveSupport::TimeZone["America/New_York"].parse("2017-02-01 7:01")
      Timecop.freeze(now) do
        subject.find_generate_and_send
      end

      expect(sent.length).to eq 1
      expect(sent.first.first).to eq shipment

      sr = shipment.sync_records.first
      expect(sr).not_to be_nil
      expect(sr.trading_partner).to eq "CI Load"
      expect(sr.sent_at).to eq now
      expect(sr.confirmed_at).to eq (now + 1.minute)
    end

    it "groups multiple shipments together by master bill" do
      shipment2 = Factory(:shipment, importer: burlington, importer_reference: "ImpRef2", master_bill_of_lading: "MASTERBILL", last_exported_from_source: "2017-02-01")

      sent = []
      expect(subject).to receive(:generate_and_send) do |shipments|
        sent << shipments

        shipments
      end

      Timecop.freeze(ActiveSupport::TimeZone["America/New_York"].parse("2017-02-01 7:01")) do
        subject.find_generate_and_send
      end

      expect(sent.length).to eq 1
      expect(sent.first.first).to eq shipment
      expect(sent.first.second).to eq shipment2

      # Make sure they're both marked as synced
      expect(shipment.sync_records.first).not_to be_nil
      expect(shipment2.sync_records.first).not_to be_nil
    end

    it "does not send shipments received less than 30 minutes ago" do
      expect(subject).not_to receive(:generate_and_send)

      now = ActiveSupport::TimeZone["America/New_York"].parse("2017-01-31 19:30")
      Timecop.freeze(now) do
        subject.find_generate_and_send
      end
    end

    it "doesn't allow an error in one send to prevent a later send" do
      shipment2 = Factory(:shipment, importer: burlington, importer_reference: "ImpRef2", master_bill_of_lading: "MASTERBILL2", last_exported_from_source: "2017-01-01")

      e = StandardError.new
      sent = []
      expect(subject).to receive(:generate_and_send).exactly(2).times do |shipments|
        # Raise an error for the first shipment received (which should be the lastest one since the results are sorted by export time)
        raise e if shipments.first.master_bill_of_lading == "MASTERBILL2"

        sent << shipments
      end

      expect(e).to receive(:log_me).with(["Master Bill: MASTERBILL2"])

      Timecop.freeze(ActiveSupport::TimeZone["America/New_York"].parse("2017-02-01 7:01")) do
        subject.find_generate_and_send
      end

      expect(sent.length).to eq 1
      expect(sent.first.first).to eq shipment

      expect(shipment2.sync_records.length).to eq 0
    end
  end
end