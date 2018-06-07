describe OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator do
  
  describe "generate_xml" do

    let (:entry_data) {
      e = described_class::CiLoadEntry.new
      e.vessel = "VESS"
      e.bills_of_lading = [described_class::CiLoadBillsOfLading.new("MBOL")]
      e
    }

    let (:shipment) {
      Shipment.new
    }

    it "generates shipment data and renders it as xml" do
      expect(subject).to receive(:generate_kewill_shipment_data).with(shipment).and_return entry_data
      doc = subject.generate_xml shipment
      # Just make sure the vessel is in the XML location we expect it to be in..
      # The specifics of XML generation is not part of this class as it's just
      # calling through to a module
      expect(doc.root.text "request/kcData/ediShipments/ediShipment/vesselAirlineName").to eq "VESS"
    end

  end

  describe "generate_kewill_shipment_data" do
    let (:importer) {
      Factory(:importer, alliance_customer_number: "CUST")
    }

    let (:us) {
      Factory(:country, iso_code: "US")
    }

    let (:cn) {
     Factory(:country, iso_code: "CN") 
    }

    let (:cdefs) {
      subject.send(:cdefs)
    }

    let (:product) {
      p = Factory(:product, name: "Part Description")
      c = p.classifications.create! country_id: us.id
      c.tariff_records.create! hts_1: "1234509876"
      p.update_custom_value! cdefs[:prod_part_number], "PARTNO"
      p
    }

    let (:order) {
      o = Factory(:order, customer_order_number: "ORDER")
      l = Factory(:order_line, product: product, order: o, country_of_origin: "VN", price_per_unit: 10)
      o
    }

    let (:shipment) {
      s = Shipment.create! reference: "REF", master_bill_of_lading: "CARR123456", house_bill_of_lading: "HBOL", vessel: "VESSEL", voyage: "VOYAGE", vessel_carrier_scac: "CARR", mode: "Ocean", 
        est_arrival_port_date: Date.new(2018, 4, 1), departure_date: Date.new(2018, 3, 1), est_departure_date: Date.new(2018, 3, 3), importer_id: importer.id,
        country_origin: cn, country_export: us

      # This is midnight UTC, so the actual date should roll back a day, since it should be using the date in Eastern TZ
      s.update_custom_value! cdefs[:shp_entry_prepared_date], "2018-06-01 00:00"

      container = s.containers.create! container_number: "CONTAINER", seal_number: "SEAL", container_size: "20FT"

      shipment_line_1 = s.shipment_lines.build gross_kgs: BigDecimal("10"), carton_qty: 20, invoice_number: "INV", quantity: 30, container_id: container.id
      shipment_line_1.linked_order_line_id = order.order_lines.first.id
      shipment_line_1.product_id = order.order_lines.first.product.id
      shipment_line_1.save!

      shipment_line_2 = s.shipment_lines.build gross_kgs: BigDecimal("40"), carton_qty: 50, invoice_number: "INV", quantity: 60, container_id: container.id
      shipment_line_2.linked_order_line_id = order.order_lines.first.id
      shipment_line_2.product_id = order.order_lines.first.product.id
      shipment_line_2.save!

      s.reload

      s
    }

    let (:goods_description) {
      DataCrossReference.create! key: "CUST", value: "GOODS", cross_reference_type: DataCrossReference::CI_LOAD_DEFAULT_GOODS_DESCRIPTION
    }

    it "generates entry data" do
      goods_description
      d = subject.generate_kewill_shipment_data shipment

      expect(d.customer).to eq "CUST"
      expect(d.vessel).to eq "VESSEL"
      expect(d.voyage).to eq "VOYAGE"
      expect(d.carrier).to eq "CARR"
      expect(d.customs_ship_mode).to eq 11
      expect(d.pieces).to eq 70
      expect(d.pieces_uom).to eq "CTNS"
      expect(d.weight_kg).to eq 50
      expect(d.goods_description).to eq "GOODS"
      expect(d.country_of_origin).to eq "CN"
      expect(d.country_of_export).to eq "US"

      expect(d.bills_of_lading.length).to eq 1
      b = d.bills_of_lading.first
      expect(b.master_bill).to eq "CARR123456"
      expect(b.house_bill).to eq "HBOL"
      expect(b.pieces).to eq 70
      expect(b.pieces_uom).to eq "CTNS"

      expect(d.containers.length).to eq 1
      c = d.containers.first
      expect(c.container_number).to eq "CONTAINER"
      expect(c.seal_number).to eq "SEAL"
      expect(c.size).to eq "20FT"
      expect(c.pieces).to eq 70
      expect(c.pieces_uom).to eq "CTNS"
      expect(c.description).to eq "GOODS"

      date = d.dates.find {|d| d.code == :est_arrival_date}
      expect(date).not_to be_nil
      expect(date.date).to eq Date.new(2018, 4, 1)

      date = d.dates.find {|d| d.code == :export_date}
      expect(date).not_to be_nil
      expect(date.date).to eq Date.new(2018, 3, 1)

      expect(d.invoices.length).to eq 1
      inv = d.invoices.first

      expect(inv.invoice_number).to eq "INV"
      expect(inv.invoice_date).to eq Date.new(2018, 05, 31)

      expect(inv.invoice_lines.length).to eq 2

      line = inv.invoice_lines.first
      expect(line.gross_weight).to eq 10
      expect(line.pieces).to eq 30
      expect(line.container_number).to eq "CONTAINER"
      expect(line.cartons).to eq 20
      expect(line.part_number).to eq "PARTNO"
      expect(line.description).to eq "Part Description"
      expect(line.hts).to eq "1234509876"
      # This comes from the PO, not the shipment header
      expect(line.country_of_origin).to eq "VN"
      expect(line.country_of_export).to eq "US"
      expect(line.unit_price).to eq 10
      expect(line.unit_price_uom).to eq "PCS"
      expect(line.po_number).to eq "ORDER"
      expect(line.foreign_value).to eq 300 
      expect(line.country_of_origin)

      line = inv.invoice_lines.second
      expect(line.gross_weight).to eq 40
      expect(line.pieces).to eq 60
      expect(line.container_number).to eq "CONTAINER"
      expect(line.cartons).to eq 50
      expect(line.part_number).to eq "PARTNO"
      expect(line.description).to eq "Part Description"
      expect(line.hts).to eq "1234509876"
      expect(line.country_of_origin).to eq "VN"
      expect(line.unit_price).to eq 10
      expect(line.unit_price_uom).to eq "PCS"
      expect(line.po_number).to eq "ORDER"
      expect(line.foreign_value).to eq 600 
    end

    it "handles shipments without invoice numbers" do
      shipment.shipment_lines.update_all invoice_number: nil

      d = subject.generate_kewill_shipment_data shipment

      expect(d.invoices).to eq []
    end

    it "handles air shipment modes" do
      shipment.mode = "Air"

      d = subject.generate_kewill_shipment_data shipment
      expect(d.customs_ship_mode).to eq 40
    end

    it "handles multiple master bills on same shipment" do
      shipment.master_bill_of_lading = "CARR123456\n CARR987654"

      d = subject.generate_kewill_shipment_data shipment
      expect(d.bills_of_lading.length).to eq 2

      b = d.bills_of_lading.first
      expect(b.master_bill).to eq "CARR123456"
      expect(b.house_bill).to eq "HBOL"
      # Pieces should be missing because we can't accurately figure them if there are multiple bills at the header
      expect(b.pieces).to be_nil

      b = d.bills_of_lading.second
      expect(b.master_bill).to eq "CARR987654"
      expect(b.house_bill).to eq "HBOL"
      expect(b.pieces).to be_nil
    end

    it "appends vessel carrier scac to master bill if it's missing" do
      shipment.master_bill_of_lading = "123456"
      d = subject.generate_kewill_shipment_data shipment
      expect(d.bills_of_lading.first.master_bill).to eq "CARR123456"
    end

    it "handles data for multiple shipments" do
      # Make sure we're also totalling piece counts /weight for shipment lines at shipment, bol, and container levels
      s2 = Shipment.new master_bill_of_lading: "CARR987654", house_bill_of_lading: "HBOL2", vessel: "VESSEL2"
      line = ShipmentLine.new gross_kgs: BigDecimal("100"), carton_qty: 50
      s2.shipment_lines << line
      container = Container.new(container_number: "CONT2", seal_number: "SEAL2")
      container.shipment_lines << line
      s2.containers << container


      d = subject.generate_kewill_shipment_data [shipment, s2]

      # Make sure the first shipment was used to build the main data
      expect(d.vessel).to eq "VESSEL"
      expect(d.weight_kg).to eq 150
      expect(d.pieces).to eq 120

      expect(d.bills_of_lading.length).to eq 2

      b = d.bills_of_lading.first
      expect(b.master_bill).to eq "CARR123456"
      expect(b.house_bill).to eq "HBOL"
      expect(b.pieces).to eq 70

      b = d.bills_of_lading.second
      expect(b.master_bill).to eq "CARR987654"
      expect(b.house_bill).to eq "HBOL2"
      expect(b.pieces).to eq 50

      expect(d.containers.length).to eq 2
      c = d.containers.first
      expect(c.container_number).to eq "CONTAINER"
      expect(c.seal_number).to eq "SEAL"
      expect(c.pieces).to eq 70

      c = d.containers.second
      expect(c.container_number).to eq "CONT2"
      expect(c.seal_number).to eq "SEAL2"
      expect(c.pieces).to eq 50
    end

    it "uses shipment country origin if PO's is blank" do
      order.order_lines.update_all country_of_origin: nil

      d = subject.generate_kewill_shipment_data shipment

      line = d.invoices.first.invoice_lines.first
      expect(line.country_of_origin).to eq "CN"
    end
  end
end