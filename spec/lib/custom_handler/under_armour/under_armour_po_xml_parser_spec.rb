describe OpenChain::CustomHandler::UnderArmour::UnderArmourPoXmlParser do

  let (:data) { IO.read "spec/fixtures/files/ua_po.xml" }
  let (:prepack_data) { IO.read "spec/fixtures/files/ua_po_prepack.xml" }
  let (:xml) { REXML::Document.new(data).root.get_elements("Orders").first }
  let (:prepack_xml) { REXML::Document.new(prepack_data).root.get_elements("Orders").first}
  let (:user) { User.integration }
  let! (:ua) { Factory(:importer, system_code: "UNDAR")}
  let! (:ua_parts) { Factory(:importer, system_code: "UAPARTS")}

  let! (:ms) {
    s = stub_master_setup
    allow(s).to receive(:custom_feature?).with("UAPARTS Staging").and_return true
    s
  }

  let(:log) { InboundFile.new }

  describe "process_order" do
    let (:cdefs) { subject.cdefs }

    it "creates a PO from xml" do
      now = Time.zone.now
      Timecop.freeze { subject.process_order xml, user, "bucket", "file.xml", log }

      order = Order.where(order_number: "UNDAR-4200001923").first

      expect(order).not_to be_nil

      expect(order.importer).to eq ua
      expect(order.customer_order_number).to eq "4200001923"
      expect(order.order_date).to eq Date.new(2016, 12, 18)
      expect(order.terms_of_sale).to eq "FOB"
      expect(order.custom_value(cdefs[:ord_revision])).to eq 208236
      expect(order.custom_value(cdefs[:ord_revision_date])).to eq now.in_time_zone("America/New_York").to_date
      expect(order.last_file_bucket).to eq "bucket"
      expect(order.last_file_path).to eq "file.xml"

      expect(order.entity_snapshots.length).to eq 1
      snap = order.entity_snapshots.first
      expect(snap.user).to eq user
      expect(snap.context).to eq "file.xml"

      expect(order.order_lines.length).to eq 2

      l = order.order_lines.first
      expect(l.line_number).to eq 10
      expect(l.quantity).to eq BigDecimal("10")
      expect(l.unit_of_measure).to eq "EA"
      expect(l.sku).to eq "1242757-001-XS"
      expect(l.price_per_unit).to eq BigDecimal("1")
      expect(l.custom_value(cdefs[:ord_line_ex_factory_date])).to eq Date.new(2016, 12, 19)
      expect(l.custom_value(cdefs[:ord_line_division])).to eq "1002-Apparel"
      p = l.product
      expect(p.unique_identifier).to eq "UAPARTS-1242757-001"
      expect(p.importer).to eq ua_parts
      expect(p.custom_value(cdefs[:prod_part_number])).to eq "1242757-001"
      expect(p.custom_value(cdefs[:prod_prepack])).to be_nil
      expect(l.variant).not_to be_nil
      expect(p.variants).to include l.variant
      expect(l.variant.variant_identifier).to eq "1242757-001-XS"

      l = order.order_lines.second
      expect(l.line_number).to eq 20
      expect(l.quantity).to eq BigDecimal("20")
      expect(l.unit_of_measure).to eq "EA"
      expect(l.sku).to eq "1242757-001-S"
      expect(l.price_per_unit).to eq BigDecimal("1")
      expect(l.custom_value(cdefs[:ord_line_ex_factory_date])).to eq Date.new(2016, 12, 19)
      expect(l.custom_value(cdefs[:ord_line_division])).to eq "1002-Apparel"
      expect(l.product).to eq p
      expect(l.variant).not_to be_nil
      expect(l.variant.variant_identifier).to eq "1242757-001-S"

      expect(p.entity_snapshots.length).to eq 1
      expect(p.entity_snapshots.first.user).to eq user
      expect(p.entity_snapshots.first.context).to eq "file.xml"

      expect(log.company).to eq ua
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].value).to eq '4200001923'
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_type).to eq "Order"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_id).to eq order.id
    end

    it "uses 'UNDAR' for products if custom feature isn't set" do
      allow(ms).to receive(:custom_feature?).with("UAPARTS Staging").and_return false

      order = subject.process_order xml, user, "bucket", "file.xml", log

      p = order.order_lines.first.product
      expect(p.importer).to eq ua
      expect(p.unique_identifier).to eq "UNDAR-1242757-001"
    end

    it "handles prepack lines" do
      # This file contains two prepack lines and three prepack component lines.  The component lines should be
      # ignored.  The resulting order should contain two lines.
      subject.process_order prepack_xml, user, "bucket", "file.xml", log

      order = Order.where(order_number: "UNDAR-4200001923").first
      expect(order).not_to be_nil

      expect(order.order_lines.length).to eq 2

      l = order.order_lines.first
      expect(l.line_number).to eq 10
      expect(l.quantity).to eq BigDecimal("66")
      expect(l.unit_of_measure).to eq "EA"
      expect(l.sku).to eq "9000003-PPK-ASST"
      expect(l.price_per_unit).to eq BigDecimal("38.72")
      expect(l.custom_value(cdefs[:ord_line_ex_factory_date])).to eq Date.new(2016, 12, 19)
      expect(l.custom_value(cdefs[:ord_line_division])).to eq "1002-Apparel"
      p = l.product
      expect(p.unique_identifier).to eq "UAPARTS-9000003"
      expect(p.importer).to eq ua_parts
      expect(p.custom_value(cdefs[:prod_part_number])).to eq "9000003"
      expect(p.custom_value(cdefs[:prod_prepack])).to eq true
      expect(l.variant).to be_nil
      expect(p.variants.length).to eq 0

      l = order.order_lines.last
      expect(l.line_number).to eq 20
      expect(l.sku).to eq "9000004-PPK-ASST"
      expect(l.product.unique_identifier).to eq "UAPARTS-9000004"
    end

    it "handles updating orders (deleting all lines)" do
      order = Factory(:order, importer: ua, order_number: "UNDAR-4200001923")
      line = Factory(:order_line, order: order)

      subject.process_order xml, user, "bucket", "file.xml", log

      order.reload
      # Just check something the parser sets to ensure the header data was definitely updated.
      expect(order.order_date).to eq Date.new(2016, 12, 18)
      expect(order.order_lines.length).to eq 2

      # Make sure the existing line was deleted
      expect { line.reload }.to raise_error ActiveRecord::RecordNotFound

      expect(order.entity_snapshots.length).to eq 1
    end

    it "raises an error if UA importer doesn't exist" do
      ua.destroy

      expect { subject.process_order xml, user, "bucket", "file.xml", log }.to raise_error "Unable to find Under Armour 'UNDAR' importer account."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq "Unable to find Under Armour 'UNDAR' importer account."
    end

    it "raises an error if UAPARTS importer doesn't exist" do
      ua_parts.destroy

      expect { subject.process_order xml, user, "bucket", "file.xml", log }.to raise_error "Unable to find Under Armour 'UAPARTS' importer account."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq "Unable to find Under Armour 'UAPARTS' importer account."
    end

    it "doesn't update order if file's revision is older than the current one" do
      order = Factory(:order, importer: ua, order_number: "UNDAR-4200001923")
      order.update_custom_value! cdefs[:ord_revision], 208237

      subject.process_order xml, user, "bucket", "file.xml", log

      order.reload
      expect(order.entity_snapshots.length).to eq 0
    end
  end

  describe "parse_file" do
    it "parses XML string" do
      subject.parse_file(data, log, bucket: "bucket", key: "file.xml")

      order = Order.where(order_number: "UNDAR-4200001923").first
      expect(order).not_to be_nil
      expect(order.last_file_bucket).to eq "bucket"
      expect(order.last_file_path).to eq "file.xml"
    end

    it "handles blank files" do
      expect(subject.parse_file("", log, bucket: "bucket", key: "file.xml")).to be_nil
    end
  end

  describe "integration_folder" do
    subject { described_class }

    it "uses the correct folder" do
      expect(subject.integration_folder).to eq ["www-vfitrack-net/_ua_po_xml", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ua_po_xml"]
    end
  end
end