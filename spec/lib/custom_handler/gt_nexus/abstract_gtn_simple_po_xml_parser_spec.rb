describe OpenChain::CustomHandler::GtNexus::AbstractGtnSimpleOrderXmlParser do
  include OpenChain::CustomHandler::NokogiriXmlHelper

  class MockGtnSimpleOrderXmlParser < OpenChain::CustomHandler::GtNexus::AbstractGtnSimpleOrderXmlParser

    def initialize
      super({})
    end

    def importer_system_code order_xml
      "SYSTEM_CODE"
    end

    def import_country order_xml, item_xml
      Country.where(iso_code: "US").first
    end

  end

  # Kirklands GT Nexus XML is the only example XML we have at the moment, so just use that for the generic case
  let (:xml_data) {
    IO.read 'spec/fixtures/files/kirklands_gtn_po.xml'
  }

  let (:xml) {
    xml_document(xml_data)
  }

  let (:cancelled_order_xml) {
    xml_data.sub!("<Purpose>CREATE</Purpose>", "<Purpose>Cancel</Purpose>")
    xml
  }

  let! (:importer) { create(:importer, system_code: "SYSTEM_CODE") }

  let(:cdefs) { subject.cdefs }

  let (:integration) { User.integration }

  let (:product) {
    p = create(:product, importer: importer, unique_identifier: "SYSTEM_CODE-219397", name: "PILLOW OPEN PLAID BLK 20IN")
    p.update_hts_for_country us, "9404901000"
    p
  }

  let (:order) {
    ol = create(:order_line, product: product, line_number: 100, order: create(:order, importer: importer, factory: factory, vendor: vendor, order_number: "SYSTEM_CODE-675974"))
    ol.order
  }

  let (:factory) {
    f = create(:company, name: "GUPTA EXIM (INDIA) PVT. LTD.", factory: true, mid: "INGUP103XXXX")
    f.system_identifiers.create! system: "SYSTEM_CODE-GTN Factory", code: "28537"
    create(:address, company: f, system_code: "SYSTEM_CODE-GTN Factory-28537", address_type: "Factory", name: "GUPTA EXIM (INDIA) PVT. LTD.", country: india, line_1: "(PLANT II)|103 DLF INDUSTRIAL AREA PHASE1", city: "FARIDABAD")
    f
  }

  let (:vendor) {
    v = create(:company, vendor: true, name: "FWS_VIVSUN EXPORT", system_code: "")
    v.system_identifiers.create! system: "SYSTEM_CODE-GTN Vendor", code: "28536"
    create(:address, company: v, system_code: "SYSTEM_CODE-GTN Vendor-28536", address_type: "Vendor", name: "FWS_VIVSUN EXPORT", country: india, line_1: "23/47 LINI RD INDUSTRIAL AREA", city: "GHAZIABAD")
    v
  }


  let (:india) { create(:country, iso_code: "IN") }
  let (:us) { create(:country, iso_code: "US")}
  let (:inbound_file) { InboundFile.new }

  subject { MockGtnSimpleOrderXmlParser.new }

  describe "process_order" do
    let! (:ms) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("WWW").and_return true
      ms
    }

    before :each do
      us
      india
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses and creates an order, parties, products" do
      o = subject.process_order xml, integration, "bucket", "key"
      o.reload

      expect(o).not_to be_nil

      expect(o.last_exported_from_source).to eq Time.zone.parse("2019-10-30T17:49:08")
      expect(o.order_number).to eq "SYSTEM_CODE-675974"
      expect(o.customer_order_number).to eq "675974"
      expect(o.importer).to eq importer
      expect(o.last_file_bucket).to eq "bucket"
      expect(o.last_file_path).to eq "key"
      expect(o.terms_of_payment).to eq "CC"
      expect(o.ship_window_start).to eq Date.new(2020, 1, 22)
      expect(o.ship_window_end).to eq Date.new(2020, 1, 28)
      expect(o.order_date).to eq Date.new(2019, 10, 30)
      expect(o.custom_value(cdefs[:ord_type])).to eq "Cross-Border"

      expect(o.entity_snapshots.length).to eq 1
      s = o.entity_snapshots.first
      expect(s.user).to eq integration
      expect(s.context).to eq "key"

      expect(inbound_file).to have_identifier "PO Number", "675974", Order, o.id

      v = o.vendor
      expect(v).not_to be_nil
      expect(v).to have_system_identifier("SYSTEM_CODE-GTN Vendor", "28536")
      expect(v.name).to eq "FWS_VIVSUN EXPORT"
      expect(v.vendor?).to eq true
      expect(o.importer.linked_companies).to include v

      a = v.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "SYSTEM_CODE-GTN Vendor-28536"
      expect(a.name).to eq "FWS_VIVSUN EXPORT"
      expect(a.line_1).to eq "23/47 LINI RD INDUSTRIAL AREA"
      expect(a.line_2).to be_nil
      expect(a.line_3).to be_nil
      expect(a.city).to eq "GHAZIABAD"
      expect(a.state).to be_nil
      expect(a.postal_code).to be_nil
      expect(a.country).to eq india

      f = o.factory
      expect(f).not_to be_nil
      expect(f).to have_system_identifier("SYSTEM_CODE-GTN Factory", "28537")
      expect(f.name).to eq "GUPTA EXIM (INDIA) PVT. LTD."
      expect(f.factory?).to eq true
      expect(f.mid).to eq "INGUP103XXXX"
      expect(o.importer.linked_companies).to include f

      a = f.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "SYSTEM_CODE-GTN Factory-28537"
      expect(a.address_type).to eq "Factory"
      expect(a.name).to eq "GUPTA EXIM (INDIA) PVT. LTD."
      expect(a.line_1).to eq "(PLANT II)|103 DLF INDUSTRIAL AREA PHASE1"
      expect(a.city).to eq "FARIDABAD"
      expect(a.country).to eq india

      agent = o.agent
      expect(agent).not_to be_nil
      expect(agent).to have_system_identifier("SYSTEM_CODE-GTN Agent", "28387")
      expect(agent.name).to eq "FLAT WORLD SOURCE INC"
      expect(agent.agent?).to eq true
      expect(o.importer.linked_companies).to include agent

      a = agent.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "SYSTEM_CODE-GTN Agent-28387"
      expect(a.name).to eq "FLAT WORLD SOURCE INC"
      expect(a.line_1).to eq "V-12 ,GREEN PARK EXTN"
      expect(a.line_2).to be_nil
      expect(a.line_3).to be_nil
      expect(a.city).to eq "NEW DELHI"
      expect(a.state).to be_nil
      expect(a.postal_code).to eq "110016"
      expect(a.country).to eq india

      ship_to = o.ship_to
      expect(ship_to).not_to be_nil
      expect(ship_to.system_code).to eq "SYSTEM_CODE-GTN Ship To-5000"
      expect(ship_to.name).to eq "Kirkland's Distribution Center"
      expect(ship_to.line_1).to eq "431 Smith Lane"
      expect(ship_to.line_2).to be_nil
      expect(ship_to.line_3).to be_nil
      expect(ship_to.city).to eq "Jackson"
      expect(ship_to.state).to eq "TN"
      expect(ship_to.postal_code).to eq "38305"
      expect(ship_to.country).to eq us
      expect(importer.addresses).to include ship_to

      expect(o.order_lines.length).to eq 1

      l = o.order_lines.first

      expect(l.line_number).to eq 5
      expect(l.quantity).to eq 360
      expect(l.unit_of_measure).to eq "Each"
      expect(l.hts).to eq "9404901000"
      expect(l.country_of_origin).to eq "IN"
      expect(l.price_per_unit).to eq BigDecimal("24.99")

      p = l.product
      expect(p.unique_identifier).to eq "SYSTEM_CODE-219397"
      expect(p.custom_value(cdefs[:prod_part_number])).to eq "219397"
      expect(p.name).to eq "PILLOW OPEN PLAID BLK 20IN"
      expect(p.hts_for_country us).to eq ["9404901000"]
    end

    it "calls all extension point methods" do
      expect(subject).to receive(:set_additional_order_information)
      expect(subject).to receive(:set_additional_order_line_information).exactly(1).times
      expect(subject).to receive(:set_additional_party_information).exactly(3).times
      expect(subject).to receive(:set_additional_company_address_information).exactly(1).times
      expect(subject).to receive(:set_additional_product_information).exactly(1).times

      subject.process_order xml, integration, "bucket", "key"
    end

    it "raises an error if invalid root element is used" do
      allow(subject).to receive(:inbound_file).and_return inbound_file
      expect { subject.process_order xml_document("<root></root>"), integration, "bucket", "key"}.to raise_error LoggedParserRejectionError, "Unexpected root element. Expected OrderMessage but found 'root'."
    end

    context "with existing data" do

      before :each do
        order
      end

      it "updates an existing order, removing unreferenced lines" do
        order_line = order.order_lines.first

        o = subject.process_order xml, integration, "bucket", "key"
        o.reload

        # We don't really need to check every single value, the update should basically be the same as the create...just validate that some things unique to an update did occur

        # Make sure the existing order line was destroyed
        expect(o.order_lines.length).to eq 1
        expect(o.order_lines.find {|l| l.line_number == 100 }).to be_nil

        expect { order_line.reload }.to raise_error ActiveRecord::RecordNotFound

        # Make sure product, factory, vendor records didn't have snapshots generated, since nothing changed
        expect(product.entity_snapshots.length).to eq 0
        expect(factory.entity_snapshots.length).to eq 0
        expect(vendor.entity_snapshots.length).to eq 0
        expect(o.entity_snapshots.length).to eq 1
      end

      it "does not process the file if the revision number is out of date" do
        order.update! last_exported_from_source: Time.zone.parse("2019-10-31T17:49:08")

        o = subject.process_order xml, integration, "bucket", "key"
        expect(o).to be_nil
        order.reload

        expect(order.last_file_path).to be_nil
        expect(order.entity_snapshots.length).to eq 0
      end

      context "with cancelled order status" do
        it "cancels an order" do
          now = Time.zone.parse("2018-08-22 12:00")

          o = nil
          Timecop.freeze(now) { o = subject.process_order cancelled_order_xml, integration, "bucket", "key" }

          expect(o.closed_at).to eq now
          expect(o.closed_by).to eq integration
          expect(o.entity_snapshots.length).to eq 1

          s = o.entity_snapshots.first
          expect(s.user).to eq integration
          expect(s.context).to eq "key"
        end

        it "does not process the file if the revision number is out of date" do
          order.update! last_exported_from_source: Time.zone.parse("2019-10-31T17:49:08")

          o = subject.process_order cancelled_order_xml, integration, "bucket", "key"
          expect(o).to be_nil
          order.reload

          expect(order.closed_at).to be_nil
          expect(order.entity_snapshots.length).to eq 0
        end
      end

      context "detecting changes " do
        it "detects changes to basic party information on an existing order and saves / snapshots them" do
          factory.update! name: "Factory"
          vendor.update! name: "Vendor"

          o = subject.process_order xml, integration, "bucket", "key"

          factory.reload
          expect(factory.name).to eq "GUPTA EXIM (INDIA) PVT. LTD."
          expect(factory.entity_snapshots.length).to eq 1

          vendor.reload
          expect(vendor.name).to eq "FWS_VIVSUN EXPORT"
          expect(vendor.entity_snapshots.length).to eq 1
        end

        it "detects changes to party address information on an existing order and saves / snapshots them" do
          factory.addresses.first.update! line_1: "Line 1"
          vendor.addresses.first.update! line_1: "Line 1"

          o = subject.process_order xml, integration, "bucket", "key"

          factory.reload
          expect(factory.addresses.first.line_1).to eq "(PLANT II)|103 DLF INDUSTRIAL AREA PHASE1"
          expect(factory.entity_snapshots.length).to eq 1

          vendor.reload
          expect(vendor.addresses.first.line_1).to eq "23/47 LINI RD INDUSTRIAL AREA"
          expect(vendor.entity_snapshots.length).to eq 1
        end

        it "detects changes to product on an existing order and saves/snapshots it" do
          product.update! name: "Name"

          o = subject.process_order xml, integration, "bucket", "key"

          product.reload
          expect(product.name).to eq "PILLOW OPEN PLAID BLK 20IN"
          expect(product.entity_snapshots.length).to eq 1
        end

        it "detects changes to product hts on an existing order and saves/snapshots it" do
          product.update_hts_for_country us, "1111111111"

          o = subject.process_order xml, integration, "bucket", "key"

          product.reload
          expect(product.hts_for_country us).to eq ["9404901000"]
          expect(product.entity_snapshots.length).to eq 1
        end
      end
    end
  end


  describe "parse_file" do
    let (:user) {
      u = User.new
      allow(User).to receive(:integration).and_return u
      u
    }

    subject { MockGtnSimpleOrderXmlParser }

    it "parses xml data and processes it" do
      expect_any_instance_of(subject).to receive(:process_order).with(instance_of(Nokogiri::XML::Document), user, "bucket", "key")

      subject.parse_file xml_data, InboundFile.new, {bucket: "bucket", key: "key"}
    end
  end
end