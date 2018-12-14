describe OpenChain::CustomHandler::Pvh::PvhGtnOrderXmlParser do

  let (:xml) {
    REXML::Document.new(IO.read 'spec/fixtures/files/pvh_gtn_po.xml')
  }

  let (:order_xml) {
    REXML::XPath.first(xml, "/Order/orderDetail")
  }

  let! (:pvh) { Factory(:importer, system_code: "PVH") }

  let (:cdefs) {
    subject.cdefs
  }

  let (:integration) { User.integration }

  let (:product) {
    p = Factory(:product, importer: pvh, unique_identifier: "PVH-6403", name: "MEN'S KNIT T SHIRT")
    p.update_hts_for_country us, "6109100012"
    p.update_custom_value! cdefs[:prod_fish_wildlife], true
    p.update_custom_value! cdefs[:prod_fabric_content], "100CTTN"
    p
  }

  let (:order) {
    ol = Factory(:order_line, product: product, line_number: 100, order: Factory(:order, importer: pvh, vendor: vendor, factory: factory, order_number: "PVH-RTCO69258"))
    ol.order
  }

  let (:factory) {
    f = Factory(:company, name: "GUPTA EXIM (INDIA) PVT. LTD.", factory: true, system_code: "PVH-Factory-21410002", mid: "INGUPEXI103FAR")
    Factory(:address, company: f, system_code: f.system_code, name: "GUPTA EXIM (INDIA) PVT. LTD.", country: india, line_1: "(PLANT II)|103 DLF INDUSTRIAL AREA PHASE1", city: "FARIDABAD")
    f
  }

  let (:vendor) {
    v = Factory(:company, vendor: true, name: "GUPTA EXIM(INDIA) PVT LTD", system_code: "PVH-Vendor-21410")
    Factory(:address, company: v, system_code: v.system_code, name: "GUPTA EXIM(INDIA) PVT LTD", country: india, line_1: "144 DLF INDUSTRIAL AREA", line_2: "|PHASE 1,FARIDABAD-121 003", city: "HARYANA", state: "07", postal_code: "122505")
    v
  }

  let (:inbound_file) { InboundFile.new }
  let (:india) { Factory(:country, iso_code: "IN") }
  let (:us) { Factory(:country, iso_code: "US")}

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

      expect(o.last_exported_from_source).to eq Time.zone.parse("20180509061943")
      expect(o.order_number).to eq "PVH-RTCO69258"
      expect(o.customer_order_number).to eq "RTCO69258"
      expect(o.importer).to eq pvh
      expect(o.last_file_bucket).to eq "bucket"
      expect(o.last_file_path).to eq "key"
      expect(o.customer_order_status).to eq "Open"
      expect(o.custom_value(cdefs[:ord_country_of_origin])).to eq "IN"
      expect(o.custom_value(cdefs[:ord_destination_code])).to eq "USJOI"
      expect(o.custom_value(cdefs[:ord_buyer])).to eq "IKLEYM"
      expect(o.mode).to eq "S"
      expect(o.terms_of_sale).to eq "FOB"
      expect(o.fob_point).to eq "INBOM"
      expect(o.currency).to eq "USD"
      expect(o.order_date).to eq Date.new(2018, 3, 5)

      expect(o.season).to eq "FALL 2018"
      expect(o.custom_value(cdefs[:ord_division])).to eq "Calvin Klein Outlets"
      expect(o.custom_value(cdefs[:ord_buyer_order_number])).to eq "C12345"
      expect(o.custom_value(cdefs[:ord_type])).to eq "SA"

      expect(o.entity_snapshots.length).to eq 1
      s = o.entity_snapshots.first
      expect(s.user).to eq integration
      expect(s.context).to eq "key"

      expect(inbound_file).to have_identifier "PO Number", "RTCO69258"

      v = o.vendor
      expect(v).not_to be_nil
      expect(v).to have_system_identifier("PVH-GTN Vendor", "21410")
      expect(v.name).to eq "GUPTA EXIM(INDIA) PVT LTD"
      expect(v.vendor?).to eq true
      expect(o.importer.linked_companies).to include v

      a = v.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "PVH-GTN Vendor-21410"
      expect(a.name).to eq "GUPTA EXIM(INDIA) PVT LTD"
      expect(a.line_1).to eq "144 DLF INDUSTRIAL AREA"
      expect(a.line_2).to eq "|PHASE 1,FARIDABAD-121 003"
      expect(a.city).to eq "HARYANA"
      expect(a.state).to eq "07"
      expect(a.postal_code).to eq "122505"
      expect(a.country).to eq india
      
      f = o.factory
      expect(f).not_to be_nil
      expect(f).to have_system_identifier("PVH-GTN Factory", "21410002")
      expect(f.name).to eq "GUPTA EXIM (INDIA) PVT. LTD."
      expect(f.factory?).to eq true
      expect(o.importer.linked_companies).to include f
      expect(f.mid).to eq "INGUPEXI103FAR"

      a = f.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "PVH-GTN Factory-21410002"
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

      expect(l.custom_value(cdefs[:ord_line_color])).to eq "010"
      expect(l.custom_value(cdefs[:ord_line_color_description])).to eq "NEW BLACK"

      p = l.product
      expect(p.unique_identifier).to eq "PVH-6403"
      expect(p.custom_value(cdefs[:prod_part_number])).to eq "6403"
      expect(p.name).to eq "MEN'S KNIT T SHIRT"
      expect(p.hts_for_country us).to eq ["6109100012"]

      expect(p.custom_value(cdefs[:prod_fish_wildlife])).to eq true
      expect(p.custom_value(cdefs[:prod_fabric_content])).to eq "100CTTN"

      expect(p.entity_snapshots.length).to eq 1
      s = p.entity_snapshots.first
      expect(s.user).to eq integration
      expect(s.context).to eq "key"


      l = o.order_lines.second

      expect(l.line_number).to eq 7
      expect(l.quantity).to eq 696
      expect(l.price_per_unit).to eq 4
      expect(l.hts).to eq "6109100012"

      expect(l.custom_value(cdefs[:ord_line_color])).to eq "047"
      expect(l.custom_value(cdefs[:ord_line_color_description])).to eq "WILD DOVE/BLACK MIX"

      p2 = l.product
      expect(p2).to eq p
    end
  end
end