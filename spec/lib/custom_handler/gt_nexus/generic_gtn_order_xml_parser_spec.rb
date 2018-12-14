describe OpenChain::CustomHandler::GtNexus::GenericGtnOrderXmlParser do 

  class MockGtnOrderXmlParser < OpenChain::CustomHandler::GtNexus::GenericGtnOrderXmlParser

    def initialize
      super({})
    end

    def importer_system_code order_xml
      "SYSTEM_CODE"
    end

    def party_system_code party_xml, party_type
      "#{party_type.to_s}-code"
    end

    def import_country order_xml, item_xml
      Country.where(iso_code: "US").first
    end

  end

  # PVH's GT Nexus XML is the only example XML we have at the moment, so just use that for the generic case
  let (:xml_data) {
    IO.read 'spec/fixtures/files/pvh_gtn_po.xml'
  }

  let (:xml) {
    REXML::Document.new(xml_data)
  }

  let (:order_xml) {
    REXML::XPath.first(xml, "/Order/orderDetail")
  }

  let (:cancelled_order_xml) {
    o = order_xml
    Array.wrap(o.elements["orderFunctionCode"]).first.text = "Cancel"
    o
  }

  let! (:importer) { Factory(:importer, system_code: "SYSTEM_CODE") }

  let(:cdefs) { subject.new.cdefs }

  let (:integration) { User.integration }

  let (:product) {
    p = Factory(:product, importer: importer, unique_identifier: "SYSTEM_CODE-6403", name: "MEN'S KNIT T SHIRT")
    p.update_hts_for_country us, "6109100012"
    p
  }

  let (:order) {
    ol = Factory(:order_line, product: product, line_number: 100, order: Factory(:order, importer: importer, vendor: vendor, factory: factory, order_number: "SYSTEM_CODE-RTCO69258"))
    ol.order
  }

  let (:factory) {
    f = Factory(:company, name: "GUPTA EXIM (INDIA) PVT. LTD.", factory: true, mid: "INGUPEXI103FAR")
    f.system_identifiers.create! system: "SYSTEM_CODE-GTN Factory", code: "factory-code"
    Factory(:address, company: f, system_code: "SYSTEM_CODE-GTN Factory-factory-code", address_type: "Factory", name: "GUPTA EXIM (INDIA) PVT. LTD.", country: india, line_1: "(PLANT II)|103 DLF INDUSTRIAL AREA PHASE1", city: "FARIDABAD")
    f
  }

  let (:vendor) {
    v = Factory(:company, vendor: true, name: "GUPTA EXIM(INDIA) PVT LTD", system_code: "")
    v.system_identifiers.create! system: "SYSTEM_CODE-GTN Vendor", code: "vendor-code"
    Factory(:address, company: v, system_code: "SYSTEM_CODE-GTN Vendor-vendor-code", address_type: "Vendor", name: "GUPTA EXIM(INDIA) PVT LTD", country: india, line_1: "144 DLF INDUSTRIAL AREA", line_2: "|PHASE 1,FARIDABAD-121 003", city: "HARYANA", state: "07", postal_code: "122505")
    v
  }


  let (:india) { Factory(:country, iso_code: "IN") }
  let (:us) { Factory(:country, iso_code: "US")}
  let (:inbound_file) { InboundFile.new }

  subject { MockGtnOrderXmlParser }

  describe "process_order" do
    before :each do 
      us
      india
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses and creates an order, parties, products" do
      o = subject.process_order order_xml, integration, "bucket", "key"
      o.reload

      expect(o).not_to be_nil

      expect(o.last_exported_from_source).to eq Time.zone.parse("20180509061943")
      expect(o.order_number).to eq "SYSTEM_CODE-RTCO69258"
      expect(o.customer_order_number).to eq "RTCO69258"
      expect(o.importer).to eq importer
      expect(o.last_file_bucket).to eq "bucket"
      expect(o.last_file_path).to eq "key"
      expect(o.customer_order_status).to eq "Open"
      expect(o.custom_value(cdefs[:ord_country_of_origin])).to eq "IN"
      expect(o.custom_value(cdefs[:ord_destination_code])).to eq "USJOI"
      expect(o.custom_value(cdefs[:ord_buyer])).to eq "IKLEYM"
      expect(o.custom_value(cdefs[:ord_type])).to eq "Purchase Order"
      expect(o.mode).to eq "S"
      expect(o.terms_of_sale).to eq "FOB"
      expect(o.fob_point).to eq "INBOM"
      expect(o.currency).to eq "USD"
      expect(o.order_date).to eq Date.new(2018, 3, 5)

      expect(o.entity_snapshots.length).to eq 1
      s = o.entity_snapshots.first
      expect(s.user).to eq integration
      expect(s.context).to eq "key"

      expect(inbound_file).to have_identifier "PO Number", "RTCO69258"

      v = o.vendor
      expect(v).not_to be_nil
      expect(v).to have_system_identifier("SYSTEM_CODE-GTN Vendor", "vendor-code")
      expect(v.name).to eq "GUPTA EXIM(INDIA) PVT LTD"
      expect(v.vendor?).to eq true
      expect(o.importer.linked_companies).to include v

      a = v.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "SYSTEM_CODE-GTN Vendor-vendor-code"
      expect(a.address_type).to eq "Vendor"
      expect(a.name).to eq "GUPTA EXIM(INDIA) PVT LTD"
      expect(a.line_1).to eq "144 DLF INDUSTRIAL AREA"
      expect(a.line_2).to eq "|PHASE 1,FARIDABAD-121 003"
      expect(a.city).to eq "HARYANA"
      expect(a.state).to eq "07"
      expect(a.postal_code).to eq "122505"
      expect(a.country).to eq india
      
      f = o.factory
      expect(f).not_to be_nil
      expect(f).to have_system_identifier("SYSTEM_CODE-GTN Factory", "factory-code")
      expect(f.name).to eq "GUPTA EXIM (INDIA) PVT. LTD."
      expect(f.factory?).to eq true
      expect(o.importer.linked_companies).to include f

      a = f.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "SYSTEM_CODE-GTN Factory-factory-code"
      expect(a.address_type).to eq "Factory"
      expect(a.name).to eq "GUPTA EXIM (INDIA) PVT. LTD."
      expect(a.line_1).to eq "(PLANT II)|103 DLF INDUSTRIAL AREA PHASE1"
      expect(a.city).to eq "FARIDABAD"
      expect(a.country).to eq india

      expect(o.order_lines.length).to eq 2

      l = o.order_lines.first

      expect(l.line_number).to eq 1
      expect(l.quantity).to eq 696
      expect(l.price_per_unit).to eq 4
      expect(l.hts).to eq "6109100012"

      p = l.product
      expect(p.unique_identifier).to eq "SYSTEM_CODE-6403"
      expect(p.custom_value(cdefs[:prod_part_number])).to eq "6403"
      expect(p.name).to eq "MEN'S KNIT T SHIRT"
      expect(p.hts_for_country us).to eq ["6109100012"]

      expect(p.entity_snapshots.length).to eq 1
      s = p.entity_snapshots.first
      expect(s.user).to eq integration
      expect(s.context).to eq "key"

      l = o.order_lines.second

      expect(l.line_number).to eq 7
      expect(l.quantity).to eq 696
      expect(l.price_per_unit).to eq 4
      expect(l.hts).to eq "6109100012"

      p2 = l.product
      expect(p2).to eq p

      expect(inbound_file).to have_identifier(:po_number, "RTCO69258", Order, o.id)
    end

    it "calls all extension point methods" do
      expect_any_instance_of(subject).to receive(:set_additional_order_information)
      expect_any_instance_of(subject).to receive(:set_additional_order_line_information).exactly(2).times
      expect_any_instance_of(subject).to receive(:set_additional_party_information).exactly(2).times
      expect_any_instance_of(subject).to receive(:set_additional_product_information).exactly(2).times

      subject.process_order order_xml, integration, "bucket", "key"
    end

    context "with existing data" do

      before :each do 
        order
      end

      it "updates an existing order, removing unreferenced lines" do
        order_line = order.order_lines.first

        o = subject.process_order order_xml, integration, "bucket", "key"
        o.reload

        # We don't really need to check every single value, the update should basically be the same as the create...just validate that some things unique to an update did occur

        # Make sure the existing order line was destroyed
        expect(o.order_lines.length).to eq 2
        expect(o.order_lines.find {|l| l.line_number == 100 }).to be_nil

        expect { order_line.reload }.to raise_error ActiveRecord::RecordNotFound

        # Make sure product, factory, vendor records didn't have snapshots generated, since nothing changed
        expect(product.entity_snapshots.length).to eq 0
        expect(factory.entity_snapshots.length).to eq 0
        expect(vendor.entity_snapshots.length).to eq 0
        expect(o.entity_snapshots.length).to eq 1
      end

      it "does not process the file if the revision number is out of date" do
        order.update_attributes! last_exported_from_source: Time.zone.parse("20180509061949")

        o = subject.process_order order_xml, integration, "bucket", "key"
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
          order.update_attributes! last_exported_from_source: Time.zone.parse("20180509061949")

          o = subject.process_order cancelled_order_xml, integration, "bucket", "key"
          expect(o).to be_nil
          order.reload

          expect(order.closed_at).to be_nil
          expect(order.entity_snapshots.length).to eq 0
        end
      end

      context "detecting changes " do
        it "detects changes to basic party information on an existing order and saves / snapshots them" do
          factory.update_attributes! name: "Factory"
          vendor.update_attributes! name: "Vendor"

          o = subject.process_order order_xml, integration, "bucket", "key"

          factory.reload
          expect(factory.name).to eq "GUPTA EXIM (INDIA) PVT. LTD."
          expect(factory.entity_snapshots.length).to eq 1
        
          vendor.reload
          expect(vendor.name).to eq "GUPTA EXIM(INDIA) PVT LTD"
          expect(vendor.entity_snapshots.length).to eq 1
        end

        it "detects changes to party address information on an existing order and saves / snapshots them" do
          factory.addresses.first.update_attributes! line_1: "Line 1"
          vendor.addresses.first.update_attributes! line_1: "Line 1"

          o = subject.process_order order_xml, integration, "bucket", "key"

          factory.reload
          expect(factory.addresses.first.line_1).to eq "(PLANT II)|103 DLF INDUSTRIAL AREA PHASE1"
          expect(factory.entity_snapshots.length).to eq 1
        
          vendor.reload
          expect(vendor.addresses.first.line_1).to eq "144 DLF INDUSTRIAL AREA"
          expect(vendor.entity_snapshots.length).to eq 1
        end

        it "detects changes to product on an existing order and saves/snapshots it" do
          product.update_attributes! name: "Name"

          o = subject.process_order order_xml, integration, "bucket", "key"

          product.reload
          expect(product.name).to eq "MEN'S KNIT T SHIRT"
          expect(product.entity_snapshots.length).to eq 1
        end

        it "detects changes to product hts on an existing order and saves/snapshots it" do
          product.update_hts_for_country us, "1111111111"

          o = subject.process_order order_xml, integration, "bucket", "key"

          product.reload
          expect(product.hts_for_country us).to eq ["6109100012"]
          expect(product.entity_snapshots.length).to eq 1
        end
      end
    end
  end


  describe "parse_file" do
    it "parses xml data and calls process_order on each orderDetail" do
      expect(subject).to receive(:process_order) do |xml, user, bucket, key|
        expect(xml.name).to eq "orderDetail"
        expect(user).to eq integration
        expect(bucket).to eq "bucket"
        expect(key).to eq "key"
      end

      subject.parse_file xml_data, InboundFile.new, {bucket: "bucket", key: "key"}
    end

    it "parses all orders present in the xml" do
      xml = <<-XML
<Order>
  <orderDetail>
    <orderNumber>1</orderNumber>
  </orderDetail>
  <orderDetail>
    <orderNumber>1</orderNumber>
  </orderDetail>
</Order>
XML
      expect(subject).to receive(:process_order).exactly(2).times
      subject.parse_file xml, InboundFile.new, {bucket: "bucket", key: "key"}
    end
  end
end