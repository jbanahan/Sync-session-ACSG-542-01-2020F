describe OpenChain::CustomHandler::Kirklands::KirklandsGtnOrderXmlParser do

  let (:xml) {
    Nokogiri::XML(IO.read 'spec/fixtures/files/kirklands_gtn_po.xml')
  }

  let (:order_xml) {
    xml.xpath("OrderMessage").first
  }

  let! (:kirklands) { FactoryBot(:importer, system_code: "KLANDS") }

  let (:cdefs) {
    subject.cdefs
  }

  let (:integration) { User.integration }

  let (:product) {
    p = FactoryBot(:product, importer: kirklands, unique_identifier: "219397", name: "PILLOW OPEN PLAID BLK 20IN")
    p.update_hts_for_country us, "9404901000"
    p
  }

  let (:order) {
    ol = FactoryBot(:order_line, product: product, line_number: 5, order: FactoryBot(:order, importer: kirklands, order_number: "675974"))
    ol.order
  }

  let (:inbound_file) { InboundFile.new }
  let (:india) { FactoryBot(:country, iso_code: "IN") }
  let (:us) { FactoryBot(:country, iso_code: "US")}

  describe "process_order_update" do
    before :each do
      us
      india
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses order data" do
      now = ActiveSupport::TimeZone["America/New_York"].now()
      o = nil
      Timecop.freeze(now) {
        o = subject.process_order_update order_xml, integration, "bucket", "key"
      }

      expect(o).not_to be_nil

      expect(o.last_exported_from_source).to eq Time.zone.parse("2019-10-30T17:49:08")
      expect(o.order_number).to eq "675974"
      expect(o.customer_order_number).to eq "675974"
      expect(o.importer).to eq kirklands
      expect(o.last_file_bucket).to eq "bucket"
      expect(o.last_file_path).to eq "key"
      expect(o.terms_of_payment).to eq "CC"
      expect(o.ship_window_start).to eq Date.new(2020, 1, 22)
      expect(o.ship_window_end).to eq Date.new(2020, 1, 28)
      expect(o.order_date).to eq Date.new(2019, 10, 30)
      expect(o.custom_value(cdefs[:ord_type])).to eq "Cross-Border"

      # Kirklands extended fields
      expect(o.custom_value(cdefs[:ord_department_code])).to eq "25"
      expect(o.custom_value(cdefs[:ord_department])).to eq "TEXTILES"

      expect(o.entity_snapshots.length).to eq 1
      s = o.entity_snapshots.first
      expect(s.user).to eq integration
      expect(s.context).to eq "key"

      expect(inbound_file).to have_identifier "PO Number", "675974", Order, o.id

      v = o.vendor
      expect(v).not_to be_nil
      expect(v).to have_system_identifier("GTN Vendor", "28536")
      expect(v.name).to eq "FWS_VIVSUN EXPORT"
      expect(v.vendor?).to eq true
      expect(o.importer.linked_companies).to include v

      a = v.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "GTN Vendor-28536"
      expect(a.name).to eq "FWS_VIVSUN EXPORT"
      expect(a.line_1).to eq "23/47 LINI RD INDUSTRIAL AREA"
      expect(a.line_2).to be_nil
      expect(a.line_3).to be_nil
      expect(a.city).to eq "GHAZIABAD"
      expect(a.state).to be_nil
      expect(a.postal_code).to be_nil
      expect(a.country).to eq india

      agent = o.agent
      expect(agent).not_to be_nil
      expect(agent).to have_system_identifier("GTN Agent", "28387")
      expect(agent.name).to eq "FLAT WORLD SOURCE INC"
      expect(agent.agent?).to eq true
      expect(o.importer.linked_companies).to include agent

      a = agent.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "GTN Agent-28387"
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
      expect(ship_to.system_code).to eq "GTN Ship To-5000"
      expect(ship_to.name).to eq "Kirkland's Distribution Center"
      expect(ship_to.line_1).to eq "431 Smith Lane"
      expect(ship_to.line_2).to be_nil
      expect(ship_to.line_3).to be_nil
      expect(ship_to.city).to eq "Jackson"
      expect(ship_to.state).to eq "TN"
      expect(ship_to.postal_code).to eq "38305"
      expect(ship_to.country).to eq us

      expect(o.order_lines.length).to eq 1

      l = o.order_lines.first

      expect(l.line_number).to eq 5
      expect(l.quantity).to eq 360
      expect(l.unit_of_measure).to eq "Each"
      expect(l.hts).to eq "9404901000"
      expect(l.country_of_origin).to eq "IN"
      expect(l.price_per_unit).to eq BigDecimal("4.85")
      expect(l.unit_msrp).to eq BigDecimal("24.99")

      p = l.product
      expect(p.unique_identifier).to eq "219397"
      expect(p.name).to eq "PILLOW OPEN PLAID BLK 20IN"
      expect(p.hts_for_country us).to eq ["9404901000"]
      expect(p.custom_value(cdefs[:prod_fob_price])).to eq BigDecimal("4.85")
      expect(p.custom_value(cdefs[:prod_country_of_origin])).to eq "IN"
      expect(p.custom_value(cdefs[:prod_vendor_item_number])).to eq "119118 BLACK"
    end
  end
end