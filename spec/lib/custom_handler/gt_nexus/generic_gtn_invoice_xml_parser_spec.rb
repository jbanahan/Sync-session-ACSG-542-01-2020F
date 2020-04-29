describe OpenChain::CustomHandler::GtNexus::GenericGtnInvoiceXmlParser do
  let (:xml_data) { IO.read 'spec/fixtures/files/gtn_generic_invoice.xml' }
  let (:xml) { REXML::Document.new(xml_data) }
  let (:invoice_xml) { REXML::XPath.first(xml, "/Invoice/invoiceDetail") }
  let! (:india) { Factory(:country, iso_code: "IN") }
  let! (:ca) { Factory(:country, iso_code: "CA") }
  let! (:importer) {
    i = Factory(:importer, system_code: "SYSTEM_CODE")
    i.system_identifiers.create! system: "GT Nexus Invoice Consignee", code: "63480155069"
    i
  }
  let (:user) { Factory(:user) }
  let (:inbound_file) { InboundFile.new }

  describe "process_invoice" do
    before :each do
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "processes xml and generates an invoice" do
      i = subject.process_invoice invoice_xml, user, "bucket", "key"

      expect(i).not_to be_nil

      expect(i.importer).to eq importer
      expect(i.invoice_number).to eq "EEGC/7469/1819"
      expect(i.last_exported_from_source).to eq Time.zone.parse("2018-08-24T06:45:12Z")
      expect(i.last_file_bucket).to eq "bucket"
      expect(i.last_file_path).to eq "key"

      expect(i.invoice_date).to eq Date.new(2018, 8, 6)
      expect(i.terms_of_sale).to eq "FOB"
      expect(i.currency).to eq "USD"
      expect(i.ship_mode).to eq "Air"
      expect(i.net_weight).to eq BigDecimal("608.36")
      expect(i.net_weight_uom).to eq "KG"
      expect(i.gross_weight).to eq BigDecimal("766.85")
      expect(i.gross_weight_uom).to eq "KG"
      expect(i.volume).to eq BigDecimal("5.445")
      expect(i.volume_uom).to eq "CR"
      expect(i.invoice_total_foreign).to eq BigDecimal("3574.08")
      expect(i.invoice_total_domestic).to eq BigDecimal("3574.08")
      expect(i.total_charges).to eq 0
      expect(i.total_discounts).to eq 0

      expect(i.entity_snapshots.length).to eq 1
      s = i.entity_snapshots.first
      expect(s.context).to eq "key"
      expect(s.user).to eq user
      expect(inbound_file).to have_identifier :invoice_number, "EEGC/7469/1819", Invoice, i.id
      expect(inbound_file).to have_identifier :po_number, "RTTC216383"
      expect(inbound_file).to have_identifier :po_number, "RTTC216384"

      v = i.vendor
      expect(v).not_to be_nil
      expect(v).to have_system_identifier("SYSTEM_CODE-GTN Vendor", "5717989018071001")
      expect(v.name).to eq "EASTMAN EXPORTS GLOBAL-"
      expect(v.addresses.length).to eq 1
      a = v.addresses.first
      expect(a.system_code).to eq "SYSTEM_CODE-GTN Vendor-5717989018071001"
      expect(a.address_type).to eq "Vendor"
      expect(a.name).to eq "EASTMAN EXPORTS GLOBAL-"
      expect(a.line_1).to eq "5/591 SRI LAKSHMI NAGAR"
      expect(a.line_2).to eq "PITCHAMPALAYAM PUDUR, TIRUPUR"
      expect(a.city).to eq "TAMILNADU"
      expect(a.postal_code).to eq "641603"
      expect(a.country).to eq india
      expect(importer.linked_companies).to include v

      expect(i.invoice_lines.length).to eq 2

      l = i.invoice_lines.first

      expect(l.line_number).to eq 1
      expect(l.po_number).to eq "RTTC216383"
      expect(l.part_number).to eq "7695775"
      expect(l.hts_number).to eq "6109100022"
      expect(l.part_description).to eq "W CROSSED TH TEE TEE-112-"
      expect(l.quantity).to eq BigDecimal("288")
      expect(l.quantity_uom).to eq "EA"
      expect(l.unit_price).to eq BigDecimal("5.84")
      expect(l.value_foreign).to eq BigDecimal("1681.92")
      expect(l.country_origin).to eq india
      expect(l.order_line).to be_nil
      expect(l.order).to be_nil
      expect(l.product).to be_nil
      expect(l.variant).to be_nil
    end

    it "falls back to using Name element to find importer by system code" do
      id = importer.system_identifiers.first
      id.update! code: "PVH CANADA, INC."

      i = subject.process_invoice invoice_xml, user, "bucket", "key"

      expect(i).not_to be_nil
      expect(i.importer).to eq importer
    end

    it "errors if importer cannot be found" do
      importer.system_identifiers.destroy_all

      expect { subject.process_invoice invoice_xml, user, "bucket", "key" }.to raise_error "No 'GT Nexus Invoice Consignee' System Identifier present for values '63480155069' or 'PVH CANADA, INC.'. Please add identifier in order to process this file."
    end

    it "errors if importer doesn't have a system code" do
      importer.update! system_code: nil
      expect { subject.process_invoice invoice_xml, user, "bucket", "key" }.to raise_error "Importer '#{importer.name}' must have a system code configured in order to receive GTN Invoice xml."
    end

    context "with existing invoice" do
      let! (:invoice) {
        Invoice.create! importer_id: importer.id, invoice_number: "EEGC/7469/1819"
      }

      let! (:invoice_line) {
        # We don't need any info, this is just to confirm that the lines get destroyed before
        # reloading
        invoice.invoice_lines.create! line_number: 1
      }

      it "updates an existing invoice" do
        i = subject.process_invoice invoice_xml, user, "bucket", "key"

        expect(i).not_to be_nil
        expect(i).to eq invoice
        expect(i.invoice_lines.length).to eq 2

        expect { invoice_line.reload }.to raise_error ActiveRecord::RecordNotFound

        # There's really nothing else to check here...destroying and recreating the lines
        # is the only real difference between create / update
      end
    end
  end
end
