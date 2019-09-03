describe OpenChain::CustomHandler::Vandegrift::KewillGenericShipmentCiLoadGenerator do

  let (:cdefs) {
    subject.cdefs
  }

  let (:us) { Factory(:country, iso_code: "US") }

  let (:product) {
    product = Factory(:product)
    product.update_custom_value! cdefs[:prod_part_number], "PARTNO"
    product.update_hts_for_country(us, "1234567890")

    product
  }

  let (:order) {
    order = Factory(:order, customer_order_number: "PO", factory: Factory(:company, factory: true, mid: "MID"))
    order_line = Factory(:order_line, order: order, country_of_origin: "CN", price_per_unit: BigDecimal("12.99"), product: product)

    order.reload
  }

  let (:shipment) {
    shipment = Factory(:shipment, master_bill_of_lading: "MBOL", importer: with_customs_management_id(Factory(:importer), "CUSTNO"))
    shipment_line = Factory(:shipment_line, shipment: shipment, product: product, carton_qty: 10, gross_kgs: BigDecimal("100.50"), quantity: 99, linked_order_line_id: order.order_lines.first.id)
    shipment_line.update_custom_value! cdefs[:shpln_invoice_number], "INVOICE"

    shipment.reload
  }

  describe "generate_entry_data" do

    it "turns shipment data into CI Load struct objects" do
      ci_load = subject.generate_entry_data shipment
      expect(ci_load).not_to be_nil

      expect(ci_load.customer).to eq "CUSTNO"
      expect(ci_load.invoices.length).to eq 1
      invoice = ci_load.invoices.first
      expect(invoice.invoice_number).to eq "INVOICE"

      expect(ci_load.invoices.first.invoice_lines.try(:length)).to eq 1
      line = ci_load.invoices.first.invoice_lines.first

      expect(line.part_number).to eq "PARTNO"
      expect(line.cartons).to eq 10
      expect(line.gross_weight).to eq BigDecimal("100.50")
      expect(line.pieces).to eq 99
      
      expect(line.po_number).to eq "PO"
      expect(line.country_of_origin).to eq "CN"
      expect(line.foreign_value).to eq BigDecimal("1286.01")
      expect(line.hts).to eq "1234567890"
      expect(line.mid).to eq "MID"

      expect(line.buyer_customer_number).to eq "CUSTNO"
      expect(line.seller_mid).to eq "MID"
    end

    it "uses alternate data locations for some fields" do
      shipment.shipment_lines.first.update_custom_value! cdefs[:shpln_coo], "VN"
      shipment.shipment_lines.first.update_custom_value! cdefs[:shpln_invoice_number], nil

      ci_load = subject.generate_entry_data shipment

      expect(ci_load.invoices.length).to eq 1
      invoice = ci_load.invoices.first
      expect(invoice.invoice_number).to eq ""

      expect(ci_load.invoices.first.invoice_lines.try(:length)).to eq 1
      line = ci_load.invoices.first.invoice_lines.first
      expect(line.country_of_origin).to eq "VN"
    end
  end

  describe "generate_and_send" do

    let (:generator) {
      instance_double(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator)
    }

    it "generates data and sends it to the kewill generator" do
      expect(generator).to receive(:generate_xls_to_google_drive).with("CUSTNO CI Load/MBOL.xls", [instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry)])

      expect(subject).to receive(:kewill_generator).and_return generator
      subject.generate_and_send shipment
    end
  end

  describe "drive_path" do
    let (:importer) { with_customs_management_id(Factory(:company), "IMP") }
    let (:shipment) { Shipment.new master_bill_of_lading: "MBOL", importer_reference: "IMPREF", reference: "REF", importer: importer }

    it "uses master bill to name the file by default" do
      expect(subject.drive_path(shipment)).to eq "IMP CI Load/MBOL.xls"
    end

    it "uses importer reference if master bill is blank" do
      shipment.master_bill_of_lading = ""
      expect(subject.drive_path(shipment)).to eq "IMP CI Load/IMPREF.xls"
    end

    it "uses reference if master bill and importer reference is blank" do
      shipment.master_bill_of_lading = ""
      shipment.importer_reference = ""

      expect(subject.drive_path(shipment)).to eq "IMP CI Load/REF.xls"
    end
  end
end