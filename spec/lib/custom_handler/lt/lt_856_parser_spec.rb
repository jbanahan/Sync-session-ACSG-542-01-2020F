describe OpenChain::CustomHandler::Lt::Lt856Parser do

   # Breakdown of the two shipments in lt_856.edi (preorder traversal)
   #       root
   #        /\
   #     s      s
   #     /\     |
   #    e  e    o
   #    /\  \   |
   #   o  o  o  i
   #  /\  / /
   # i i i i

  subject { described_class }

  let!(:cdefs) { subject.new.cdefs }
  let(:data) { IO.read 'spec/fixtures/files/lt_856.edi' }
  let(:data_abridged) { IO.read 'spec/fixtures/files/lt_856_abridged.edi' }
  let(:data_missing_container) { IO.read 'spec/fixtures/files/lt_856_missing_container.edi' }
  let(:lt) { Factory(:importer, system_code: "LOLLYT") }
  let(:vietnam) { Factory(:country, iso_code: "VN") }
  let(:sri_lanka) { Factory(:country, iso_code: "LK") }
  let(:ord_1) { Factory(:order, importer: lt, customer_order_number: "613430") }
  let(:ord_2) { Factory(:order, importer: lt, customer_order_number: "416475") }
  let(:ord_3) { Factory(:order, importer: lt, customer_order_number: "613450") }
  let(:ord_4) { Factory(:order, importer: lt, customer_order_number: "416495") }

  let(:ordln_1) { Factory(:order_line, order: ord_1, sku: "192399348778")}
  let(:ordln_2) { Factory(:order_line, order: ord_1, sku: "192399348761")}
  let(:ordln_3) { Factory(:order_line, order: ord_2, sku: "192399348631")}
  let(:ordln_4) { Factory(:order_line, order: ord_3, sku: "192399348662")}
  let(:ordln_5) { Factory(:order_line, order: ord_4, sku: "192399348648")}

  let(:port_receipt_1) { Factory(:port, schedule_k_code: "55224")}
  let(:port_unlading_1) { Factory(:port, schedule_d_code: "2709")}
  let(:port_final_dest_1) { Factory(:port, schedule_d_code: "2710")}
  let(:port_lading_1) { Factory(:port, schedule_k_code: "55200")}
  let(:port_last_foreign_1) { Factory(:port, schedule_k_code: "12345")}

  let(:port_receipt_2) { Factory(:port, schedule_k_code: "54201")}
  let(:port_unlading_2) { Factory(:port, schedule_d_code: "1001")}
  let(:port_final_dest_2) { Factory(:port, schedule_d_code: "1002")}
  let(:port_lading_2) { Factory(:port, schedule_k_code: "54301")}
  let(:port_last_foreign_2) { Factory(:port, schedule_k_code: "54321")}


  def load_all
    vietnam; ordln_1; ordln_2; ordln_3; ordln_4; port_receipt_1; port_unlading_1; port_final_dest_1; port_lading_1;
    port_last_foreign_1; load_for_shipment_2
  end

  def load_for_shipment_2
    sri_lanka; ordln_5; port_receipt_2; port_unlading_2; port_final_dest_2; port_lading_2;
    port_last_foreign_2;
  end

  describe "parse", :disable_delayed_jobs do
    it "creates a shipment" do
      load_all
      now = DateTime.new(2018, 3, 15, 6)
      Timecop.freeze(DateTime.new(2018, 3, 15, 6)) { subject.parse data, bucket: "bucket", key: "file.edi" }

      shipment = Shipment.where(importer_id: lt.id, reference: "LOLLYT-20998").first
      expect(shipment).not_to be_nil
      expect(shipment.importer_reference).to eq "20998"
      expect(shipment.last_exported_from_source).to eq DateTime.new(2018, 9, 17, 21, 6)
      expect(shipment.master_bill_of_lading).to eq "APLU715214446"
      expect(shipment.mode).to eq "Ocean"
      expect(shipment.vessel).to eq "CMA CGM THAMES"
      expect(shipment.country_origin).to eq vietnam
      expect(shipment.voyage).to eq "0TU1BE"
      expect(shipment.vessel_carrier_scac).to eq "APLU"
      expect(shipment.est_arrival_port_date).to eq Date.new(2018, 8, 15)
      expect(shipment.est_departure_date).to eq Date.new(2018, 7, 30)

      expect(shipment.first_port_receipt).to eq port_receipt_1
      expect(shipment.unlading_port).to eq port_unlading_1
      expect(shipment.final_dest_port).to eq port_final_dest_1
      expect(shipment.lading_port).to eq port_lading_1
      expect(shipment.last_foreign_port).to eq port_last_foreign_1
      expect(shipment.custom_value(cdefs[:shp_entry_prepared_date])).to eq now

      expect(shipment.containers.count).to eq 2
      c1, c2 = shipment.containers
      expect(c1.container_number).to eq "CMAU5209148"
      expect(c1.seal_number).to eq "F5032887"
      expect(c1.container_size).to eq "4B"
      expect(c2.container_number).to eq "TGBU5072396"
      expect(c2.seal_number).to eq "F5032804"
      expect(c2.container_size).to eq "4C"

      expect(c1.shipment_lines.count).to eq 3
      sl1, sl2, sl3 = c1.shipment_lines
      expect(sl1.shipment).to eq shipment
      expect(sl1.order_lines.first.order).to eq ord_1
      expect(sl1.quantity).to eq 5568
      expect(sl1.carton_qty).to eq 464
      expect(sl1.cbms).to eq 16.017
      expect(sl1.gross_kgs).to eq 2227.200
      expect(sl1.invoice_number).to eq "KD009"

      expect(sl2.shipment).to eq shipment
      expect(sl2.order_lines.first.order).to eq ord_1
      expect(sl2.quantity).to eq 4236
      expect(sl2.carton_qty).to eq 353
      expect(sl2.cbms).to eq 12.185
      expect(sl2.gross_kgs).to eq 1694.400
      expect(sl2.invoice_number).to eq "KD010"

      expect(sl3.shipment).to eq shipment
      expect(sl3.order_lines.first.order).to eq ord_2
      expect(sl3.quantity).to eq 150
      expect(sl3.carton_qty).to eq 25
      expect(sl3.cbms).to eq 0.419
      expect(sl3.gross_kgs).to eq 62.500
      expect(sl3.invoice_number).to eq "LLG18HO09"

      expect(c2.shipment_lines.count).to eq 1
      sl4 = c2.shipment_lines.first
      expect(sl4.shipment).to eq shipment
      expect(sl4.order_lines.first.order).to eq ord_3
      expect(sl4.quantity).to eq 6312
      expect(sl4.carton_qty).to eq 325
      expect(sl4.cbms).to eq 25.015
      expect(sl4.gross_kgs).to eq 128.37
      expect(sl4.invoice_number).to eq "KD011"

      expect(shipment.entity_snapshots.length).to eq 1
      snap1 = shipment.entity_snapshots.first
      expect(snap1.user).to eq User.integration
      expect(snap1.context).to eq "file.edi"

      # without container
      shipment2 = Shipment.where(importer_id: lt.id, reference: "LOLLYT-21213").first
      expect(shipment2).not_to be_nil
      expect(shipment2.last_exported_from_source).to eq DateTime.new(2018, 9, 18, 21, 7)
      expect(shipment2.master_bill_of_lading).to eq "ONEYCMBU07934600"
      expect(shipment2.mode).to eq "Air"
      expect(shipment2.vessel).to eq "CRETE I"
      expect(shipment2.country_origin).to eq sri_lanka
      expect(shipment2.voyage).to eq "003E"
      expect(shipment2.vessel_carrier_scac).to eq "ONEY"
      expect(shipment2.est_arrival_port_date).to eq Date.new(2018, 9, 30)
      expect(shipment2.est_departure_date).to eq Date.new(2018, 9, 10)

      expect(shipment2.first_port_receipt).to eq port_receipt_2
      expect(shipment2.unlading_port).to eq port_unlading_2
      expect(shipment2.final_dest_port).to eq port_final_dest_2
      expect(shipment2.lading_port).to eq port_lading_2
      expect(shipment2.last_foreign_port).to eq port_last_foreign_2

      expect(shipment2.containers.count).to eq 0
      expect(shipment2.shipment_lines.count).to eq 1
      sl5 = shipment2.shipment_lines.first
      expect(shipment2.custom_value(cdefs[:shp_entry_prepared_date])).to eq now

      expect(sl5.order_lines.first.order).to eq ord_4
      expect(sl5.quantity).to eq 552
      expect(sl5.carton_qty).to eq 92
      expect(sl5.cbms).to eq 3.329
      expect(sl5.gross_kgs).to eq 264.040
      expect(sl5.invoice_number).to eq "L-117"

      expect(shipment2.entity_snapshots.length).to eq 1
      snap2 = shipment2.entity_snapshots.first
      expect(snap2.user).to eq User.integration
      expect(snap2.context).to eq "file.edi"
    end

    it "replaces an existing shipment" do
      load_all
      s = Factory :shipment, importer_id: lt.id, reference: "LOLLYT-20998", master_bill_of_lading: "mbol"

      container = Factory(:container, shipment: s, container_number: 'cont num')
      Factory(:shipment_line, shipment: s, container: container, product: ordln_1.product, linked_order_line_id: ordln_1, quantity: 50)

      subject.parse data, bucket: "bucket", key: "file.edi"

      expect { s.reload }.to_not raise_error
      expect(Shipment.count).to eq 2
      expect(s.master_bill_of_lading).to eq "APLU715214446"
      expect(s.containers.length).to eq 2
      expect(s.shipment_lines.length).to eq 4

      c = s.containers.first

      # Just check for some data from the EDI to be present
      expect(c.container_number).to eq "CMAU5209148"
      expect(c.shipment_lines.length).to eq 3
      line = s.shipment_lines.find { |sl| sl.container == c }
      expect(line.quantity).to eq 5568
    end

    it "doesn't process outdated EDI" do
      load_for_shipment_2
      s = Shipment.create!(importer_id: lt.id, reference: "LOLLYT-21213", last_exported_from_source: DateTime.new(2018, 10, 1))
      subject.parse data_abridged, bucket: "bucket", key: "file.edi"
      s = Shipment.where(importer_id: lt.id, reference: "LOLLYT-21213").first

      # If master bill was nil, it means nothing was processed
      expect(s.master_bill_of_lading).to be_nil
    end

    it "leaves missing port codes blank" do
      load_for_shipment_2
      port_receipt_2.destroy
      subject.parse data_abridged, bucket: "bucket", key: "file.edi"
      s = Shipment.where(importer_id: lt.id, reference: "LOLLYT-21213").first

      expect(s.first_port_receipt).to be_nil
    end

    it "errors if LT is missing" do
      load_for_shipment_2
      lt.destroy
      expect { subject.parse data_abridged, bucket: "bucket", key: "file.edi" }.to raise_error "No importer found with System Code LOLLYT."
    end

    it "errors if order is missing" do
      load_for_shipment_2
      ordln_5.order.destroy
      expect { subject.parse data_abridged, bucket: "bucket", key: "file.edi" }.to raise_error OpenChain::EdiParserSupport::EdiBusinessLogicError, "<br>LT orders are missing for the following Order Numbers:<br>416495"
    end

    it "errors if order line is missing" do
      load_for_shipment_2
      ordln_5.destroy
      expect { subject.parse data_abridged, bucket: "bucket", key: "file.edi" }.to raise_error OpenChain::EdiParserSupport::EdiBusinessLogicError, "<br>LT order lines are missing for the following Order / UPC pairs:<br>416495 / 192399348648"
    end

    it "errors if container is missing for ocean shipment" do
      load_all
      expect { subject.parse data_missing_container, bucket: "bucket", key: "file.edi" }.to raise_error OpenChain::EdiParserSupport::EdiBusinessLogicError, "<br>LT containers are missing for the following ocean Shipment: LOLLYT-20998"
    end
  end
end
