describe OpenChain::CustomHandler::Vandegrift::KewillInvoiceGenerator do

  describe "generate_invoice" do
    let (:importer) {
      with_customs_management_id(create(:importer), "IMP")
    }
    let (:other_importer) { with_customs_management_id(create(:importer), "AHH")}

    let (:coo) {
      c = Country.new
      c.iso_code = "CO"
      c
    }

    let (:coe) {
      c = Country.new
      c.iso_code = "CE"
      c
    }

    let! (:prs) { create(:unit_of_measure, uom: "PRS", description: "Pairs") }
    let! (:pcs) { create(:unit_of_measure, uom: "PCS", description: "Pieces") }
    let! (:too) { create(:unit_of_measure, uom: "TOO", description: "Alsoness") }
    let! (:data_cross_reference) { DataCrossReference.create! cross_reference_type: "unit_of_measure", key: pcs.uom,
      value: prs.uom, company: importer }
    let! (:another_data_cross_reference) { DataCrossReference.create! cross_reference_type: "unit_of_measure", key: prs.uom,
      value: "TOO", company: other_importer }

    let (:invoice) {
      i = Invoice.new
      i.invoice_number = "INV"
      i.invoice_date = Date.new(2018, 9, 5)
      i.currency = "USD"
      i.importer = importer

      l = i.invoice_lines.build
      l.po_number = "PO"
      l.part_number = "PART"
      l.country_origin = coo
      l.country_export = coe
      l.gross_weight = 123
      l.hts_number = "1234567890"
      l.value_foreign = BigDecimal("100")
      l.mid = "MID"
      l.unit_price = BigDecimal("10.10")
      l.part_description = "Description"
      l.quantity_uom = "BEE"
      l.quantity = BigDecimal("10")
      l.customs_quantity = BigDecimal("1")
      l.customs_quantity_uom = "UOM"
      l.spi = "SP"
      l.spi2 = "S"
      l.department = "DEPT"
      l.cartons = 5
      l.middleman_charge = BigDecimal("25")
      l.related_parties = true
      l.container_number = "CONT123456789"

      i
    }

    it "generates invoice data to ci load objects" do
      ce = subject.generate_invoice invoice

      expect(ce).to be_a described_class::CiLoadEntry

      expect(ce.file_number).to eq "INV"
      expect(ce.customer).to eq "IMP"
      expect(ce.invoices.length).to eq 1
      ci = ce.invoices.first

      expect(ci.invoice_number).to eq "INV"
      expect(ci.invoice_date).to eq Date.new(2018, 9, 5)
      expect(ci.currency).to eq "USD"

      expect(ci.invoice_lines.length).to eq 1
      cl = ci.invoice_lines.first

      expect(cl.po_number).to eq "PO"
      expect(cl.part_number).to eq "PART"
      expect(cl.country_of_origin).to eq "CO"
      expect(cl.country_of_export).to eq "CE"
      expect(cl.gross_weight).to eq 123
      expect(cl.hts).to eq "1234567890"
      expect(cl.foreign_value).to eq 100
      expect(cl.mid).to eq "MID"
      expect(cl.unit_price).to eq 10.10
      expect(cl.description).to eq "Description"
      expect(cl.pieces).to eq 10
      expect(cl.quantity_1).to eq 1
      expect(cl.uom_1).to eq "UOM"
      expect(cl.spi).to eq "SP"
      expect(cl.spi2).to eq "S"
      expect(cl.department).to eq "DEPT"
      expect(cl.cartons).to eq 5
      expect(cl.first_sale).to eq 75
      expect(cl.related_parties).to eq true
      expect(cl.container_number).to eq "CONT123456789"
    end

    it "returns nil if the given uom is not known or cross referenced" do
      ce = subject.generate_invoice invoice
      expect(ce).to be_a described_class::CiLoadEntry

      ci = ce.invoices.first
      cl = ci.invoice_lines.first
      expect(cl.pieces_uom).to eq nil
    end

    it "defaults the unit of measure to PCS if it is blank" do
      invoice.invoice_lines.first.quantity_uom = ""
      ce = subject.generate_invoice invoice
      expect(ce).to be_a described_class::CiLoadEntry

      ci = ce.invoices.first
      cl = ci.invoice_lines.first
      expect(cl.pieces_uom).to eq "PCS"
    end

    it "changes the pieces unit of measure if there is a cross reference for change" do
      invoice.invoice_lines.first.quantity_uom = "PCS"
      ce = subject.generate_invoice invoice
      expect(ce).to be_a described_class::CiLoadEntry

      ci = ce.invoices.first
      cl = ci.invoice_lines.first
      expect(cl.pieces_uom).to eq "PRS"
    end

    it "ignores cross references for other company UOM" do
      invoice.invoice_lines.first.quantity_uom = "TOO"
      ce = subject.generate_invoice invoice
      expect(ce).to be_a described_class::CiLoadEntry

      ci = ce.invoices.first
      cl = ci.invoice_lines.first
      expect(cl.pieces_uom).to eq "TOO"
    end

    it "handles gross weight imperial conversion" do
      invoice.invoice_lines.first.gross_weight_uom = "LB"

      ce = subject.generate_invoice invoice
      expect(ce.invoices.first.invoice_lines.first.gross_weight).to eq BigDecimal("55.79")
    end

    it "rounds gross weight to 1 KG if it's under 1" do
      invoice.invoice_lines.first.gross_weight = BigDecimal(".01")
      ce = subject.generate_invoice invoice
      expect(ce.invoices.first.invoice_lines.first.gross_weight).to eq BigDecimal("1")
    end

    it "converts gross weight G to KG" do
      invoice.invoice_lines.first.gross_weight = BigDecimal("2000")
      invoice.invoice_lines.first.gross_weight_uom = "G"

      ce = subject.generate_invoice invoice
      expect(ce.invoices.first.invoice_lines.first.gross_weight).to eq BigDecimal("2")
    end

    it "converts gross weight LB to KG" do
      invoice.invoice_lines.first.gross_weight = BigDecimal("2000")
      invoice.invoice_lines.first.gross_weight_uom = "LB"

      ce = subject.generate_invoice invoice
      expect(ce.invoices.first.invoice_lines.first.gross_weight).to eq BigDecimal("907.18")
    end

    it "skips first sale calculation if middleman_charge is missing" do
      invoice.invoice_lines.first.middleman_charge = nil
      ce = subject.generate_invoice invoice
      expect(ce.invoices.first.invoice_lines.first.first_sale).to be_nil
    end
  end

  describe "generate_and_send_invoice" do
    let (:ci_entry) { described_class::CiLoadEntry.new }
    let (:invoice) { Invoice.new }
    let (:ci_load_generator) { instance_double OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator }
    let (:sync_record) { SyncRecord.new }

    it "generates invoice data and uses ci load generator to send it" do
      expect(subject).to receive(:generate_invoice).with(invoice).and_return ci_entry
      expect(subject).to receive(:generator).and_return ci_load_generator
      expect(ci_load_generator).to receive(:generate_and_send).with(ci_entry, {sync_record: sync_record})

      subject.generate_and_send_invoice invoice, sync_record
    end
  end
end
