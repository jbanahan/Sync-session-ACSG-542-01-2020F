require 'spec_helper'

describe OpenChain::CustomHandler::Ascena::AscenaShipmentCiLoadGenerator do

  let (:cdefs) {
    subject.cdefs
  }

  let (:product) {
    product = Factory(:product)
    product.update_custom_value! cdefs[:prod_part_number], "PARTNO"
    product.update_custom_value! cdefs[:prod_department_code], "DEPT"
    product
  }

  let (:order) {
    order = Factory(:order, customer_order_number: "PO")
    order.update_custom_value! cdefs[:ord_type], "AGS"
    order_line = Factory(:order_line, order: order, country_of_origin: "CN", price_per_unit: BigDecimal("12.99"), product: product)

    order.reload
  }

  let (:shipment) {
    shipment = Factory(:shipment, house_bill_of_lading: "HB", reference: "REF/REF")
    shipment_line = Factory(:shipment_line, shipment: shipment, product: product, carton_qty: 10, gross_kgs: BigDecimal("100.50"), quantity: 99, linked_order_line_id: order.order_lines.first.id)

    shipment.reload
  }

  describe "generate_entry_data" do

    it "turns shipment data into CI Load struct objects" do
      ci_load = subject.generate_entry_data shipment
      expect(ci_load).not_to be_nil

      expect(ci_load.customer).to eq "ASCE"
      expect(ci_load.invoices.length).to eq 1

      expect(ci_load.invoices.first.invoice_lines.try(:length)).to eq 1
      line = ci_load.invoices.first.invoice_lines.first

      expect(line.part_number).to eq "PARTNO"
      expect(line.department).to eq "DEPT"
      expect(line.cartons).to eq 10
      expect(line.gross_weight).to eq BigDecimal("100.50")
      expect(line.pieces).to eq 99
      expect(line.buyer_customer_number).to eq "ASCE"
      expect(line.po_number).to eq "PO"
      expect(line.country_of_origin).to eq "CN"
      expect(line.foreign_value).to eq BigDecimal("1286.01")
    end

    it "skips order info if PO is NONAGS order" do
      order.update_custom_value! cdefs[:ord_type], "NONAGS"

      ci_load = subject.generate_entry_data shipment
      line = ci_load.invoices.first.invoice_lines.first
      expect(line.po_number).to eq "PO"
      expect(line.country_of_origin).to be_nil
      expect(line.foreign_value).to be_nil
    end

    it "handles missing orders" do
      shipment.shipment_lines.first.piece_sets.destroy_all

      ci_load = subject.generate_entry_data shipment
      expect(ci_load.invoices.length).to eq 1

      expect(ci_load.invoices.first.invoice_lines.try(:length)).to eq 1
      line = ci_load.invoices.first.invoice_lines.first

      expect(line.part_number).to eq "PARTNO"
      expect(line.cartons).to eq 10
      expect(line.gross_weight).to eq BigDecimal("100.50")
      expect(line.pieces).to eq 99
      expect(line.buyer_customer_number).to eq "ASCE"
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
        expect(path).to eq "Ascena CI Load/file.xls"
        received_spreadsheet = Spreadsheet.open file.path
      end

      subject.send_xls_to_google_drive wb, "file.xls"

      expect(received_spreadsheet).not_to be_nil
      expect(received_spreadsheet.worksheet("sheet")).not_to be_nil
    end
  end

  describe "generate_and_send" do

    let (:wb) {
      wb, sheet = XlsMaker.create_workbook_and_sheet "sheet", ["header"]
      wb
    }

    let (:generator) {
      g = instance_double(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator)
      expect(g).to receive(:generate_xls).and_return wb
      g
    }

    it "generates xls data and sends it to google drive" do
      received_spreadsheet = nil
      expect(OpenChain::GoogleDrive).to receive(:upload_file) do |account, path, file|
        expect(account).to eq "integration@vandegriftinc.com"
        expect(path).to eq "Ascena CI Load/REF_REF.xls"
        received_spreadsheet = Spreadsheet.open file.path
      end

      expect(subject).to receive(:kewill_generator).and_return generator
      subject.generate_and_send shipment

      # Just make sure the spreadsheet has the expected sheet name and header row
      expect(received_spreadsheet).not_to be_nil
      expect(received_spreadsheet.worksheet("sheet")).not_to be_nil
    end
  end
end