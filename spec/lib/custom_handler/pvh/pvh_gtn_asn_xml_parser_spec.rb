describe OpenChain::CustomHandler::Pvh::PvhGtnAsnXmlParser do

  let (:xml_data) { IO.read 'spec/fixtures/files/gtn_pvh_asn.xml' }
  let (:xml) { REXML::Document.new(xml_data) }
  let (:asn_xml) { REXML::XPath.first(xml, "/ASNMessage/ASN") }
  let (:india) { Factory(:country, iso_code: "IN") }
  let (:ca) { Factory(:country, iso_code: "CA") }
  let (:pvh) { Factory(:importer, system_code: "PVH") }
  let (:user) { Factory(:user) }
  let (:order) { Factory(:order, order_number: "PVH-RTTC216384", importer: pvh)}
  let (:product) { Factory(:product, unique_identifier: "PVH-7696164") }
  let (:order_line_1) { Factory(:order_line, order: order, line_number: 1, product: product) }
  let (:order_line_2) { Factory(:order_line, order: order, line_number: 2, product: product) }
  let (:lading_port) { Factory(:port, name: "Chennai", iata_code: "MAA")}
  let (:unlading_port) { Factory(:port, name: "Montréal", iata_code: "YUL")}
  let (:final_dest_port) { Factory(:port, name: "Montreal-Dorval Apt", unlocode: "CAYUL") }
  let (:inbound_file) { InboundFile.new }
  let (:cdefs) { subject.cdefs }
  let (:invoice) { 
    i = Invoice.create! invoice_number: "EEGC/7469/1819", importer_id: pvh.id
    line = i.invoice_lines.create! po_number: "RTTC216384", part_number: "7696164", mid: "MYKULRUB669TAI"
    i
  }

  describe "process_asn_update" do

    before :each do 
      india
      ca
      pvh
      order_line_1
      order_line_2
      invoice
      lading_port
      unlading_port
      final_dest_port
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "creates an ocean shipment" do
      s = subject.process_asn_update asn_xml, user, "bucket", "key"

      expect(s).not_to be_nil
      expect(s.importer).to eq pvh
      expect(s.reference).to eq "PVH-5093094M01"
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
      expect(s.description_of_goods).to eq "WEARING APPAREL"

      expect(s.est_departure_date).to eq Date.new(2018, 8, 12)
      expect(s.est_arrival_port_date).to eq Date.new(2018, 8, 17)

      expect(s.lading_port).to eq lading_port
      expect(s.unlading_port).to eq unlading_port
      expect(s.final_dest_port).to eq final_dest_port
      expect(s.gross_weight).to eq BigDecimal("82.2")
      expect(s.volume).to eq BigDecimal("0.59")
      expect(s.number_of_packages).to eq 50
      expect(s.number_of_packages_uom).to eq "CTN"
      expect(s.custom_value(cdefs[:shp_entry_prepared_date])).not_to be_nil

      expect(s.entity_snapshots.length).to eq 1
      snap = s.entity_snapshots.first
      expect(snap.user).to eq user
      expect(snap.context).to eq "key"

      expect(inbound_file).to have_identifier("Shipment Reference Number", "5093094M01")

      expect(s.vendor).not_to be_nil
      expect(s.vendor).to have_system_identifier("PVH-GTN Vendor", "23894")
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

      expect(s.containers.length).to eq 1
      c = s.containers.first
      expect(c.container_number).to eq "SGIND25321"
      expect(c.container_size).to eq "ANYA"
      expect(c.fcl_lcl).to eq "LCL"
      expect(c.seal_number).to eq "SEAL"
      expect(c.goods_description).to eq "WEARING APPAREL"

      expect(c.shipment_lines.length).to eq 2

      l = c.shipment_lines.first
      expect(l.invoice_number).to eq "EEGC/7469/1819"
      expect(l.carton_qty).to eq 27
      expect(l.quantity).to eq BigDecimal("324")
      expect(l.gross_kgs).to eq BigDecimal("44.388")
      expect(l.cbms).to eq BigDecimal("0.319")
      expect(l.product).to eq product
      expect(l.order_lines.first).to eq order_line_1
      expect(l.mid).to eq "MYKULRUB669TAI"

      l = c.shipment_lines.second
      expect(l.invoice_number).to eq "EEGC/7469/1819"
      expect(l.carton_qty).to eq 23
      expect(l.quantity).to eq BigDecimal("276")
      expect(l.gross_kgs).to eq BigDecimal("37.812")
      expect(l.cbms).to eq BigDecimal("0.271")
      expect(l.product).to eq product
      expect(l.order_lines.first).to eq order_line_2
      expect(l.mid).to eq "MYKULRUB669TAI"
    end
  end

  describe "set_additional_shipment_information" do
    it "uses house bill as masterbill if masterbill is blank" do
      s = Shipment.new house_bill_of_lading: "HBOL"

      subject.set_additional_shipment_information s, nil
      expect(s.master_bill_of_lading).to eq "HBOL"
      expect(s.house_bill_of_lading).to be_nil
    end
  end
end