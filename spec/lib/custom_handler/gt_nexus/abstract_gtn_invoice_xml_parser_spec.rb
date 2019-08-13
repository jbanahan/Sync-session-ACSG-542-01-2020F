describe OpenChain::CustomHandler::GtNexus::AbstractGtnInvoiceXmlParser do

  class MockGtnInvoiceXmlParser < OpenChain::CustomHandler::GtNexus::AbstractGtnInvoiceXmlParser
    def initialize config = {}
      super(config)
    end

    def importer_system_code order_xml
      "SYSTEM_CODE"
    end

    def party_system_code party_xml, party_type
      "#{party_type.to_s}-code"
    end
  end

  let (:xml_data) {
    IO.read 'spec/fixtures/files/gtn_generic_invoice.xml'
  }

  let (:xml) {
    REXML::Document.new(xml_data)
  }

  let (:invoice_xml) {
    REXML::XPath.first(xml, "/Invoice/invoiceDetail")
  }

  let (:india) { Factory(:country, iso_code: "IN") }
  let (:ca) { Factory(:country, iso_code: "CA") }
  let (:importer) { Factory(:importer, system_code: "SYSTEM_CODE") }
  let (:user) { Factory(:user) }
  let (:order) { Factory(:order, order_number: "SYSTEM_CODE-RTTC216384", importer: importer)}
  let (:product) { Factory(:product, unique_identifier: "SYSTEM_CODE-7695775") }
  let (:variant) { Factory(:variant, product: product) }
  let (:order_line) { Factory(:order_line, order: order, line_number: 1, product: product, variant: variant) }
  let (:inbound_file) { InboundFile.new }

  subject { MockGtnInvoiceXmlParser.new }

  describe "process_invoice" do
    before :each do 
      india
      ca
      importer
      order_line
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses an invoice from xml" do
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
      expect(v).to have_system_identifier("SYSTEM_CODE-GTN Vendor", "vendor-code")
      expect(v.name).to eq "EASTMAN EXPORTS GLOBAL-"
      expect(v.addresses.length).to eq 1
      a = v.addresses.first
      expect(a.system_code).to eq "SYSTEM_CODE-GTN Vendor-vendor-code"
      expect(a.address_type).to eq "Vendor"
      expect(a.name).to eq "EASTMAN EXPORTS GLOBAL-"
      expect(a.line_1).to eq "5/591 SRI LAKSHMI NAGAR"
      expect(a.line_2).to eq "PITCHAMPALAYAM PUDUR, TIRUPUR" 
      expect(a.city).to eq "TAMILNADU"
      expect(a.postal_code).to eq "641603"
      expect(a.country).to eq india
      expect(importer.linked_companies).to include v

      expect(importer.addresses.length).to eq 1
      st = importer.addresses.first
      expect(st.system_code).to eq "SYSTEM_CODE-GTN Ship To-ship_to-code"
      expect(st.address_type).to eq "Ship To"
      expect(st.line_1).to eq "7445 Cote-de Liesse"
      expect(st.city).to eq "Montreal, QC"
      expect(st.postal_code).to eq "H4T 1G2"
      expect(st.country).to eq ca

      expect(i.invoice_lines.length).to eq 2

      l = i.invoice_lines.first

      expect(l.line_number).to eq 1
      # Even though this po number came last in the sample, it should be sorted to first
      # in the parsed invoice
      expect(l.po_number).to eq "RTTC216383"
      expect(l.part_number).to eq "7695775"
      expect(l.hts_number).to eq "6109100022"
      expect(l.part_description).to eq "W CROSSED TH TEE TEE-112-"
      expect(l.quantity).to eq BigDecimal("288")
      expect(l.quantity_uom).to eq "EA"
      expect(l.unit_price).to eq BigDecimal("5.84")
      expect(l.value_foreign).to eq BigDecimal("1681.92")
      expect(l.country_origin).to eq india

      # This is all nil on purpose (xml has it matching to order line 2), 
      # testing that we can have missing order lines
      expect(l.order_line).to be_nil
      expect(l.order).to be_nil
      expect(l.product).to be_nil
      expect(l.variant).to be_nil
      

      l = i.invoice_lines.second
      expect(l.line_number).to eq 2
      expect(l.po_number).to eq "RTTC216384"
      expect(l.part_number).to eq "7695775"
      expect(l.hts_number).to eq "6109100022"
      expect(l.part_description).to eq "W CROSSED TH TEE TEE-112-"
      expect(l.quantity).to eq BigDecimal("324")
      expect(l.quantity_uom).to eq "EA"
      expect(l.unit_price).to eq BigDecimal("5.84")
      expect(l.value_foreign).to eq BigDecimal("1892.16")
      # Make sure the order line match data pulls over.
      expect(l.order_line).to eq order_line
      expect(l.order).to eq order
      expect(l.product).to eq product
      expect(l.variant).to eq variant
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

        expect { invoice_line.reload }.to raise_error ActiveRecord::RecordNotFound

        # There's really nothing else to check here...destroying and recreating the lines
        # is the only real difference between create / update
      end

      it "skips file if current invoice is newer than XML" do
        invoice.update_attributes! last_exported_from_source: "2018-08-29 12:00"

        i = subject.process_invoice invoice_xml, user, "bucket", "key"

        # Nil return indicates the invoice xml was not processed
        expect(i).to be_nil
      end
    end

    context "with error conditions" do

      it "errors if no eventDateTime is sent" do
        ev = REXML::XPath.first(invoice_xml, "subscriptionEvent/eventDateTime")
        ev.text = ""

        expect { subject.process_invoice invoice_xml, user, "bucket", "key" }.to raise_error "All GT Nexus Invoice documents must have a eventDateTime that is a valid timestamp."
      end

      it "errors if invoice number is missing" do
        invoice_xml.elements["invoiceNumber"].text = ""

        expect { subject.process_invoice invoice_xml, user, "bucket", "key" }.to raise_error "All GT Nexus Invoice files must have an invoice number."
      end

      it "errors if top-level invoiceItem is missing the baseItem element" do
        item = REXML::XPath.first(invoice_xml, "invoiceItem")
        item.delete_element "baseItem"

        expect { subject.process_invoice invoice_xml, user, "bucket", "key" }.to raise_error "All invoiceItem elements must have a baseItem child element."
      end

      it "errors if missing order line error flag is set to true and no order line exists" do
        order_line.destroy

        allow_any_instance_of(MockGtnInvoiceXmlParser).to receive(:inbound_file).and_return inbound_file
        expect { MockGtnInvoiceXmlParser.new(error_if_missing_order_line: true).process_invoice invoice_xml, user, "bucket", "key" }.to raise_error "Failed to find order line for Order Number 'RTTC216384' / Line Number '001'."
      end
    end

    it "does not add system code prefixes if option is set to false" do
      p = MockGtnInvoiceXmlParser.new(prefix_identifiers_with_system_codes: false)
      allow(p).to receive(:inbound_file).and_return inbound_file
      i = p.process_invoice invoice_xml, user, "bucket", "key" 

      expect(i.vendor).to have_system_identifier("GTN Vendor", "vendor-code")
      expect(i.factory).to have_system_identifier("GTN Factory", "factory-code")
      expect(i.importer.addresses.first.system_code).to eq "GTN Ship To-ship_to-code"
    end

    it "calls all extension point methods" do
      expect(subject).to receive(:set_additional_invoice_information)
      expect(subject).to receive(:set_additional_invoice_line_information).exactly(2).times
      expect(subject).to receive(:set_additional_party_information).exactly(2).times

      subject.process_invoice invoice_xml, user, "bucket", "key"
    end

    it "does not look up orders if option is set to false" do
      p = MockGtnInvoiceXmlParser.new(link_to_orders: false)
      allow(p).to receive(:inbound_file).and_return inbound_file
      i = p.process_invoice invoice_xml, user, "bucket", "key"
      expect(i).not_to be_nil

      i.invoice_lines.each {|l| expect(l.order_line).to be_nil }
    end

  end

  describe "parse" do
    subject { MockGtnInvoiceXmlParser }

    it "invokes process_invoice" do
      expect_any_instance_of(subject).to receive(:process_invoice) do |instance, inv, user, bucket, key|
        expect(inv.name).to eq "invoiceDetail"
        expect(user.username).to eq "integration"
        expect(bucket).to eq "bucket"
        expect(key).to eq "key"
      end

      subject.parse(xml_data, {bucket: "bucket", key: "key"})
    end
  end

  describe "translate_ship_mode" do
    [
      ["A", "Air"], ["AE", "Air"], ["AF", "Air"], ["SE", "Air"],
      ["S", "Ocean"], ["VE", "Ocean"], 
      ["T", "Truck"],
      ["R", "Rail"], 
      ["Something else", nil], [nil, nil]
    ].each do |params|

      it "translates '#{params[0]}' to '#{params[1]}'" do
        expect(subject.translate_ship_mode params[0]).to eq params[1]
      end
    end
  end
end