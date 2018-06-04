describe OpenChain::CustomHandler::Advance::AdvancePrep7501ShipmentParser do

  let (:xml_path) { "spec/fixtures/files/advan_prep_7501.xml"}
  let (:xml) { REXML::Document.new IO.read(xml_path) }
  let (:user) { Factory(:user) }
  let (:advance_importer) { Factory(:importer, system_code: "ADVAN") }
  let (:carquest_importer) { Factory(:importer, system_code: "CQ") }
  let (:cn) { Factory(:country, iso_code: "CN") }
  let (:us) { Factory(:country, iso_code: "US") }
  let (:lading_port) { Factory(:port, name: "Qingdao", schedule_k_code: "57047") }
  let (:unlading_port) { Factory(:port, name: "Norfolk", schedule_d_code: "1401") }
  let (:final_dest) { Factory(:port, name: "Roanoke", unlocode: "USROA") }
  # This makes sure the UNLocode is the prefered code utilized.
  let (:final_dest_d) { Factory(:port, name: "Roanoke", schedule_d_code: "1234") }
  let (:cdefs) { subject.send(:cdefs) }

  describe "parse" do

    before :each do 
      advance_importer
      cn
      us
      lading_port
      unlading_port
      final_dest
      final_dest_d
    end

    it "creates parties, parts, orders, shipment" do
      s = subject.parse xml, user, xml_path

      expect(s).not_to be_nil
      expect(s).to be_persisted

      expect(s.reference).to eq "ADVAN-OERT205702H00096"
      expect(s.last_exported_from_source).to eq Time.zone.parse("2018-02-03 03:15:14")
      expect(s.house_bill_of_lading).to eq "OERT205702H00096"
      expect(s.mode).to eq "Ocean"
      expect(s.voyage).to eq "45E"
      expect(s.vessel).to eq "ZIM ROTTERDAM"
      expect(s.house_bill_of_lading).to eq "OERT205702H00096"
      expect(s.est_departure_date).to eq Date.new(2018, 1, 28)
      expect(s.departure_date).to eq Date.new(2018, 1, 29)
      expect(s.est_arrival_port_date).to eq Date.new(2018, 3, 2)
      expect(s.lading_port).to eq lading_port
      expect(s.unlading_port).to eq unlading_port
      expect(s.final_dest_port).to eq final_dest

      snap = s.entity_snapshots.first
      expect(snap.context).to eq xml_path
      expect(snap.user).to eq user

      ship_from = s.ship_from
      expect(ship_from).not_to be_nil
      expect(ship_from.company).to eq advance_importer
      expect(ship_from.address_type).to eq "Supplier"
      expect(ship_from.name).to eq "Shandong Longji Machinery Co., Ltd."
      expect(ship_from.line_1).to eq "Longkou Economic Development Zone"
      expect(ship_from.line_2).to be_nil
      expect(ship_from.line_3).to be_nil
      expect(ship_from.city).to eq "Longkou"
      expect(ship_from.state).to eq "CN"
      expect(ship_from.country).to eq cn
      expect(ship_from.postal_code).to eq "265716"

      consignee = s.consignee
      expect(consignee).not_to be_nil
      expect(consignee.name).to eq "Advance Stores Company Inc."
      expect(consignee).to be_consignee
      expect(advance_importer.linked_companies).to include consignee

      consignee.reload
      address = consignee.addresses.first
      expect(address).not_to be_nil
      expect(address.address_type).to eq "Consignee"
      expect(address.name).to eq "Advance Stores Company Inc."
      expect(address.line_1).to eq "5008 Airport Rd"
      expect(address.line_2).to be_nil
      expect(address.line_3).to be_nil
      expect(address.city).to eq "Roanoke"
      expect(address.state).to eq "VA"
      expect(address.country).to eq us
      expect(address.postal_code).to eq "24012"

      expect(consignee.system_code).to eq "ADVAN-#{address.address_hash}"

      ship_to = s.ship_to
      expect(ship_to).not_to be_nil
      expect(ship_to.company).to eq advance_importer
      expect(ship_to.address_type).to eq "ShipmentFinalDest"
      expect(ship_to.name).to eq "DC 11 (Roanoke, VA)"
      expect(ship_to.line_1).to be_nil
      expect(ship_to.line_2).to be_nil
      expect(ship_to.line_3).to be_nil
      expect(ship_to.city).to eq "Roanoke"
      expect(ship_to.state).to eq "VA"
      expect(ship_to.country).to eq us
      expect(ship_to.postal_code).to be_nil

      expect(s.containers.length).to eq 1
      c = s.containers.first
      
      expect(c.container_number).to eq "ZIMU1269903"
      expect(c.container_size).to eq "D20"
      expect(c.fcl_lcl).to eq "FCL"
      expect(c.seal_number).to eq "ZGLP117168"

      lines = s.shipment_lines
      expect(lines.length).to eq 2

      # It's not obvious, but this is also testing that the line items are being
      # sorted based on their PO and Line Item Numbers.  The ordering of the XML
      # is not the order the data is loaded - the spec xml has line 9 before line 8.
      l = lines.first
      expect(l.container).to eq c
      expect(l.invoice_number).to eq "LJ180090"
      expect(l.carton_qty).to eq 80
      expect(l.quantity).to eq 80
      expect(l.gross_kgs).to eq BigDecimal("648")
      expect(l.cbms).to eq BigDecimal("0.64")

      p = l.product
      expect(p.unique_identifier).to eq "ADVAN-11401806"
      expect(p.name).to eq "Painted rotor 1 EA CQPRT"
      expect(p.custom_value(cdefs[:prod_part_number])).to eq "11401806"
      expect(p.entity_snapshots.length).to eq 1
      snap = p.entity_snapshots.first
      expect(snap.context).to eq xml_path
      expect(snap.user).to eq user

      ps = l.piece_sets.first
      expect(ps).not_to be_nil
      ol = ps.order_line
      expect(ol).not_to be_nil

      expect(ol.line_number).to eq 8
      expect(ol.quantity).to eq 80
      expect(ol.unit_of_measure).to eq "Each"
      expect(ol.price_per_unit).to eq BigDecimal("10.33")
      expect(ol.currency).to eq "USD"
      expect(ol.country_of_origin).to eq "CN"
      expect(ol.product).to eq p

      o = ol.order
      expect(o.order_number).to eq "ADVAN-8373111-11"
      expect(o.customer_order_number).to eq "8373111-11"
      expect(o.importer).to eq advance_importer
      expect(o.entity_snapshots.length).to eq 1
      snap = o.entity_snapshots.first
      expect(snap.context).to eq xml_path
      expect(snap.user).to eq user
    end

    it "updates an existing shipment" do
      # Make sure it's clearing existing containers / lines
      shipment_line = Factory(:shipment_line, shipment: Factory(:shipment, importer: advance_importer, reference: "ADVAN-OERT205702H00096"))
      shipment = shipment_line.shipment
      container = shipment.containers.create! container_number: "1234"

      s = subject.parse xml, user, xml_path
      expect(s).to eq shipment

      # The easiest way to check that the shipment_line and container were deleted
      expect { shipment_line.reload }.to raise_error ActiveRecord::RecordNotFound
      expect { container.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "skips updating shipments when the xml is outdated" do
      shipment = Factory(:shipment, importer: advance_importer, reference: "ADVAN-OERT205702H00096", last_exported_from_source: Time.zone.parse("2018-05-01"))

      expect(subject.parse xml, user, xml_path).to be_nil
    end

    it "handles Carquest" do
      carquest_importer
      consignee = REXML::XPath.first xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'Consignee']/Name"
      consignee.text = "CARQUEST"
      
      s = subject.parse xml, user, xml_path

      expect(s.importer).to eq carquest_importer
    end

    it "raises an error if importer cannot be located" do
      consignee = REXML::XPath.first xml, "Prep7501Message/Prep7501/ASN/PartyInfo[Type = 'Consignee']/Name"
      consignee.text = "Spaceballs: The Importer"

      expect { subject.parse xml, user, xml_path }.to raise_error "Failed to find Importer account for Consignee name 'Spaceballs: The Importer'."
    end
  end

  describe "parse" do
    subject { described_class }

    it "initializes a new instance and calls parse on it" do
      expect_any_instance_of(described_class).to receive(:parse).with(instance_of(REXML::Document), User.integration, "s3_path")
      subject.parse(IO.read(xml_path), {key: "s3_path"})
    end
  end
end