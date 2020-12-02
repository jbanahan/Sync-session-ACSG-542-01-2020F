describe OpenChain::CustomHandler::GtNexus::AbstractGtnAsnXmlParser do

  class FakeGtnAsnXmlParser < OpenChain::CustomHandler::GtNexus::AbstractGtnAsnXmlParser # rubocop:disable RSpec/LeakyConstantDeclaration

    def initialize config = {}
      super(config)
    end

    def importer_system_code _xml
      "SYS"
    end

    def party_system_code party_xml, _party_type
      party_xml.text "Code"
    end
  end

  subject { FakeGtnAsnXmlParser.new }

  let (:xml_data) { IO.read 'spec/fixtures/files/gtn_generic_asn.xml' }
  let (:xml) { REXML::Document.new(xml_data) }
  let (:asn_xml) { REXML::XPath.first(xml, "/ASNMessage/ASN") }
  let (:india) { create(:country, iso_code: "IN") }
  let (:ca) { create(:country, iso_code: "CA") }
  let (:importer) { create(:importer, system_code: "SYS") }
  let (:user) { create(:user) }
  let (:order) { create(:order, order_number: "SYS-RTTC216384", customer_order_number: "RTTC216384", importer: importer)}
  let (:product) { create(:product, importer: importer, unique_identifier: "SYS-7696164") }
  let (:order_line_1) { create(:order_line, order: order, line_number: 1, product: product) }
  let (:order_line_2) { create(:order_line, order: order, line_number: 2, product: product) }
  let (:lading_port) { create(:port, name: "Chennai", iata_code: "MAA")}
  let (:unlading_port) { create(:port, name: "Montréal", iata_code: "YUL")}
  let (:final_dest_port) { create(:port, name: "Montreal-Dorval Apt", unlocode: "CAYUL") }
  let (:inbound_file) { InboundFile.new s3_path: "/path/to/file.xml"}

  describe "process_asn_update" do

    before do
      india
      ca
      importer
      order_line_1
      order_line_2
      lading_port
      unlading_port
      final_dest_port
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "creates an ocean shipment" do
      # Make sure sorted_line_items is called as it's important that this is done, so that extending
      # parsers can potentially return items in a differently sorted order
      expect(subject).to receive(:sorted_line_items).and_call_original
      s = subject.process_asn_update asn_xml, user, "bucket", "key"

      expect(s).not_to be_nil
      expect(s.importer).to eq importer
      expect(s.reference).to eq "SYS-5093094M01"
      expect(s.importer_reference).to eq "5093094M01"
      expect(s.last_exported_from_source).to eq Time.zone.parse("2018-08-23T06:19:56.060-07:00")
      expect(s.last_file_bucket).to eq "bucket"
      expect(s.last_file_path).to eq "key"
      expect(s.voyage).to eq "EK0543"
      expect(s.vessel).to eq "EK0543"
      expect(s.mode).to eq "Ocean"
      expect(s.vessel_carrier_scac).to eq "SGTA"
      expect(s.master_bill_of_lading).to eq "SGTA01449867322"
      expect(s.house_bill_of_lading).to eq "SGIND25321"
      expect(s.country_origin).to eq india
      expect(s.country_export).to eq india
      expect(s.country_import).to eq ca

      expect(s.est_departure_date).to eq Date.new(2018, 8, 12)
      expect(s.est_arrival_port_date).to eq Date.new(2018, 8, 17)

      expect(s.lading_port).to eq lading_port
      expect(s.unlading_port).to eq unlading_port
      expect(s.final_dest_port).to eq final_dest_port
      expect(s.gross_weight).to eq BigDecimal("82.2")
      expect(s.volume).to eq BigDecimal("0.59")
      expect(s.number_of_packages).to eq 50
      expect(s.number_of_packages_uom).to eq "CTN"

      expect(s.vendor).not_to be_nil
      expect(s.vendor).to have_system_identifier("SYS-GTN Vendor", "23894")
      expect(s.vendor.name).to eq "EASTMAN EXPORTS GLOBAL-"
      # Specialized address handling had to be added, since asn/order addresses are different
      a = s.vendor.addresses.first
      expect(a).not_to be_nil
      expect(a.line_1).to eq "5/591 SRI LAKSHMI NAGAR"
      expect(a.line_2).to eq "PITCHAMPALAYAM PUDUR, TIRUPUR"
      expect(a.city).to eq "Tiruppur"
      expect(a.postal_code).to eq "641603"
      expect(a.country).to eq india
      expect(s.vendor.entity_snapshots.length).to eq 1
      snap = s.vendor.entity_snapshots.first
      expect(snap.user).to eq user
      expect(snap.context).to eq "key"

      expect(s.entity_snapshots.length).to eq 1
      snap = s.entity_snapshots.first
      expect(snap.user).to eq user
      expect(snap.context).to eq "key"
      expect(inbound_file).to have_identifier :shipment_number, "5093094M01", Shipment, s.id
      expect(inbound_file).to have_identifier :master_bill, "SGTA01449867322"
      expect(inbound_file).to have_identifier :house_bill, "SGIND25321"
      expect(inbound_file).to have_identifier :container_number, "SGIND25321"
      expect(inbound_file).to have_identifier :po_number, "RTTC216384", Order, order.id
      expect(inbound_file).to have_identifier :invoice_number, "EEGC/7469/1819"

      expect(s.containers.length).to eq 1
      c = s.containers.first
      expect(c.container_number).to eq "SGIND25321"
      expect(c.container_size).to eq "ANYA"
      expect(c.fcl_lcl).to eq "LCL"
      expect(c.seal_number).to eq "SEAL"

      expect(c.shipment_lines.length).to eq 2

      l = c.shipment_lines.first
      expect(l.invoice_number).to eq "EEGC/7469/1819"
      expect(l.carton_qty).to eq 27
      expect(l.quantity).to eq BigDecimal("324")
      expect(l.gross_kgs).to eq BigDecimal("44.388")
      expect(l.cbms).to eq BigDecimal("0.319")
      expect(l.product).to eq product
      expect(l.order_lines.first).to eq order_line_1

      l = c.shipment_lines.second
      expect(l.invoice_number).to eq "EEGC/7469/1819"
      expect(l.carton_qty).to eq 23
      expect(l.quantity).to eq BigDecimal("276")
      expect(l.gross_kgs).to eq BigDecimal("37.812")
      expect(l.cbms).to eq BigDecimal("0.271")
      expect(l.product).to eq product
      expect(l.order_lines.first).to eq order_line_2
    end

    it "creates an air shipment" do
      REXML::XPath.first(asn_xml, "Mode").text = "Air"
      s = subject.process_asn_update asn_xml, user, "bucket", "key"
      expect(s.mode).to eq "Air"
      expect(s.vessel_carrier_scac).to eq "EK"
    end

    it "updates a shipment" do
      shipment = create(:shipment, reference: "SYS-5093094M01", importer: importer)
      container = create(:container, shipment: shipment, container_number: "SGIND25321")
      line = shipment.shipment_lines.create! product: product, container: container

      s = subject.process_asn_update asn_xml, user, "bucket", "key"
      expect(s).to eq shipment

      expect { line.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not update a shipment if xml is outdated" do
      shipment = create(:shipment, reference: "SYS-5093094M01", importer: importer, last_exported_from_source: "2018-09-10 12:00")
      s = subject.process_asn_update asn_xml, user, "bucket", "key"
      expect(s).to be_nil
      shipment.reload
      expect(shipment.importer_reference).to be_nil
    end

    it "raises an error if the order cannot be found" do
      order.destroy
      expect { subject.process_asn_update asn_xml, user, "bucket", "key" }.to raise_error "All errors must be fixed before this ASN can be processed."
      expect(inbound_file).to have_reject_message "PO Number 'RTTC216384' could not be found."
    end

    it "raises an error if the order line cannot be found" do
      order_line_1.destroy
      expect { subject.process_asn_update asn_xml, user, "bucket", "key" }.to raise_error "Failed to find PO Line Number '001' on PO Number 'RTTC216384'."
    end

    it "calls all extension point methods" do
      expect(subject).to receive(:set_additional_shipment_information)
      expect(subject).to receive(:set_additional_party_information)
      expect(subject).to receive(:set_additional_container_information)
      expect(subject).to receive(:set_additional_shipment_line_information).twice

      subject.process_asn_update asn_xml, user, "bucket", "key"
    end

    context "with alternate configurations" do
      it "does not use system code prefixes" do
        parser = FakeGtnAsnXmlParser.new(prefix_identifiers_with_system_codes: false)
        allow(parser).to receive(:inbound_file).and_return inbound_file
        order.update! order_number: "RTTC216384"

        s = parser.process_asn_update asn_xml, user, "bucket", "key"
        expect(s.reference).to eq "5093094M01"
        expect(s.vendor).not_to be_nil
        expect(s.vendor).to have_system_identifier("GTN Vendor", "23894")
      end
    end

    context "it creates shell orders if instructed" do

      let(:cdefs) { subject.cdefs }

      context "with prefixed system codes" do
        subject { FakeGtnAsnXmlParser.new(create_missing_purchase_orders: true) }

        it "creates shipment and generates PO and Product data" do
          Order.destroy_all
          Product.destroy_all

          s = subject.process_asn_update asn_xml, user, "bucket", "key"

          order = Order.all.first
          product = Product.all.first

          l = s.shipment_lines.first
          expect(l.invoice_number).to eq "EEGC/7469/1819"
          expect(l.carton_qty).to eq 27
          expect(l.quantity).to eq BigDecimal("324")
          expect(l.gross_kgs).to eq BigDecimal("44.388")
          expect(l.cbms).to eq BigDecimal("0.319")
          expect(l.product).to eq product
          expect(l.order_lines.first).to eq order.order_lines.first

          ol = order.order_lines.first
          expect(ol.product).to eq product
          expect(ol.line_number).to eq 1

          l = s.shipment_lines.second
          expect(l.invoice_number).to eq "EEGC/7469/1819"
          expect(l.carton_qty).to eq 23
          expect(l.quantity).to eq BigDecimal("276")
          expect(l.gross_kgs).to eq BigDecimal("37.812")
          expect(l.cbms).to eq BigDecimal("0.271")
          expect(l.product).to eq product
          expect(l.order_lines.first).to eq order.order_lines.second

          ol = order.order_lines.second
          expect(ol.product).to eq product
          expect(ol.line_number).to eq 2

          expect(order.order_number).to eq "SYS-RTTC216384"
          expect(order.customer_order_number).to eq "RTTC216384"
          expect(order.entity_snapshots.length).to eq 1
          s = order.entity_snapshots.first
          expect(s.user).to eq user
          expect(s.context).to eq inbound_file.s3_path

          expect(product.unique_identifier).to eq "SYS-7696164"
          expect(product.custom_value(cdefs[:prod_part_number])).to eq "7696164"
          expect(product.importer).to eq importer
          expect(product.entity_snapshots.length).to eq 1
          s = product.entity_snapshots.first
          expect(s.user).to eq user
          expect(s.context).to eq inbound_file.s3_path
        end

        it "adds lines to an existing order if the line is missing" do
          # Just change the line number on the existing order line record so then the asn process will construct a new record
          order_line_1.update! line_number: 10

          subject.process_asn_update asn_xml, user, "bucket", "key"

          order.reload
          expect(order.order_lines.length).to eq 3
        end

      end

      context "without system identifiers" do
        subject { FakeGtnAsnXmlParser.new(create_missing_purchase_orders: true, prefix_identifiers_with_system_codes: false) }

        it "does not prefix system codes on orders and products if not specified" do
          Order.destroy_all
          Product.destroy_all

          subject.process_asn_update asn_xml, user, "bucket", "key"

          order = Order.all.first
          product = Product.all.first

          expect(order.order_number).to eq "RTTC216384"
          expect(order.customer_order_number).to be_nil
          expect(product.unique_identifier).to eq "7696164"
          expect(product.custom_value(cdefs[:prod_part_number])).to be_nil
        end
      end
    end
  end

  describe "process_asn_cancel" do
    let (:shipment) { create(:shipment, reference: "SYS-5093094M01", importer: importer) }

    it "cancels the shipment" do
      shipment

      expect_any_instance_of(Shipment).to receive(:cancel_shipment!) do |instance, user, opts|
        expect(instance).to eq shipment
        expect(user).to eq user
        expect(opts[:canceled_date]).to eq Time.zone.parse("2018-08-23T06:19:56.060-07:00")
        expect(opts[:snapshot_context]).to eq "key"
        nil
      end

      s = subject.process_asn_cancel asn_xml, user, "bucket", "key"
      expect(s).to eq shipment
      expect(s.last_exported_from_source).to eq Time.zone.parse("2018-08-23T06:19:56.060-07:00")
      expect(s.last_file_bucket).to eq "bucket"
      expect(s.last_file_path).to eq "key"
    end

    it "does not cancel a shipment if xml is outdated" do
      shipment.update! last_exported_from_source: Time.zone.now

      s = subject.process_asn_update asn_xml, user, "bucket", "key"
      expect(s).to be_nil

      shipment.reload
      expect(shipment.canceled_date).to be_nil
    end
  end

  describe "sorted_line_items" do

    def create_container line_items
      "<Container>#{line_items.join}</Container>"
    end

    def create_line invoice, po, line
      "<LineItems><InvoiceNumber>#{invoice}</InvoiceNumber><PONumber>#{po}</PONumber><LineItemNumber>#{line}</LineItemNumber></LineItems>"
    end

    it "sorts lines based on Invoice #, PO Number, Line Number" do
      container = create_container([
                                     create_line("INV-C", "PO-B", "1"),
                                     create_line("INV-A", "PO-Z", "1"),
                                     create_line("INV-A", "PO-A", "2"),
                                     create_line("INV-A", "PO-A", "1")
                                   ])

      items = subject.sorted_line_items(REXML::Document.new(container).root)

      i = items.first
      expect(i.text("InvoiceNumber")).to eq "INV-A"
      expect(i.text("PONumber")).to eq "PO-A"
      expect(i.text("LineItemNumber")).to eq "1"

      i = items[1]
      expect(i.text("InvoiceNumber")).to eq "INV-A"
      expect(i.text("PONumber")).to eq "PO-A"
      expect(i.text("LineItemNumber")).to eq "2"

      i = items[2]
      expect(i.text("InvoiceNumber")).to eq "INV-A"
      expect(i.text("PONumber")).to eq "PO-Z"
      expect(i.text("LineItemNumber")).to eq "1"

      i = items.last
      expect(i.text("InvoiceNumber")).to eq "INV-C"
      expect(i.text("PONumber")).to eq "PO-B"
      expect(i.text("LineItemNumber")).to eq "1"
    end
  end

  describe "parse" do
    subject { FakeGtnAsnXmlParser }

    let (:integration) { User.integration }

    it "parses a file" do
      expect(subject).to receive(:process_asn) do |xml, user, bucket, key|
        expect(xml).to be_a(REXML::Element)
        expect(xml.name).to eq "ASN"
        expect(user).to eq integration
        expect(bucket).to eq "bucket"
        expect(key).to eq "key"
      end

      subject.parse_file xml_data, nil, key: "key", bucket: "bucket"
    end

    it "raises an error if invalid root element is used" do
      allow(subject).to receive(:inbound_file).and_return inbound_file
      expect { subject.parse_file "<root></root>", inbound_file}.to raise_error LoggedParserRejectionError, "Unexpected root element. Expected ASNMessage but found 'root'."
    end
  end

  describe "parse_asn" do
    subject { FakeGtnAsnXmlParser }

    it "uses update asn method" do
      expect_any_instance_of(subject).to receive(:process_asn_update).with(xml, user, "bucket", "key")
      subject.process_asn xml, user, "bucket", "key"
    end

    it "uses cancel asn method" do
      REXML::XPath.first(asn_xml, "PurposeCode").text = "Delete"

      expect_any_instance_of(subject).to receive(:process_asn_cancel).with(asn_xml, user, "bucket", "key")
      subject.process_asn asn_xml, user, "bucket", "key"
    end
  end

end