require 'spec_helper'

describe OpenChain::CustomHandler::Ellery::Ellery856Parser do
  let(:data) { IO.read 'spec/fixtures/files/ellery_856.edi' }
  let(:cdefs) { described_class.new.cdefs }
  let!(:ellery) { Factory(:importer, system_code: "ELLHOL") }

  before(:all) { described_class.new.cdefs }
  after(:all) { CustomDefinition.destroy_all }

  describe "parse", :disable_delayed_jobs do
    let!(:product) do
      prod = Factory(:product, importer: ellery, unique_identifier: "ELLHOL-17363BEDDFULMUL")
      prod.update_custom_value! cdefs[:prod_part_number], "17363BEDDFULMUL"

      prod
    end

    let!(:product_2) do
      prod = Factory(:product, importer: ellery, unique_identifier: "ELLHOL-17363BEDDKNGMUL")
      prod.update_custom_value! cdefs[:prod_part_number], "17363BEDDKNGMUL"

      prod
    end

    let!(:order) do
      order = Factory(:order, importer: ellery, order_number: "ELLHOL-60460", customer_order_number: "60460")
      Factory(:order_line, order: order, product: product)
      Factory(:order_line, order: order, product: product_2)
      order
    end

    let!(:lading) { Factory(:port, name: "MONTREAL", unlocode: "CAMTR")}
    let!(:unlading) { Factory(:port, name: "QUEBEC", unlocode: "CAQUE")}
    let!(:last_origin) { Factory(:port, name: "SEOUL", unlocode: "KRSEL")}
    let!(:discharge) { Factory(:port, name: "HANOI", unlocode: "VNHAN")}

    subject { described_class }

    it "creates a shipment" do
      subject.parse data, bucket: "bucket", key: "file.edi"

      shipment = Shipment.where(importer_id: ellery.id, reference: "ELLHOL-974J000427SH0").first
      expect(shipment).not_to be_nil
      expect(shipment.importer_reference).to eq "974J000427SH0"
      expect(shipment.last_exported_from_source).to eq DateTime.new(2017,12,11,8,2)
      expect(shipment.master_bill_of_lading).to eq "APLU067467875\n APLU012345678"
      expect(shipment.last_file_bucket).to eq "bucket"
      expect(shipment.last_file_path).to eq "file.edi"
      expect(shipment.vessel).to eq "COSCO DEVELOPMENT"
      expect(shipment.voyage).to eq "039E"
      expect(shipment.vessel_carrier_scac).to eq "APLU"
      expect(shipment.mode).to eq "Ocean"
      expect(shipment.lading_port).to eq lading
      expect(shipment.unlading_port).to eq unlading
      expect(shipment.destination_port).to eq discharge 
      expect(shipment.last_foreign_port).to eq last_origin

      expect(shipment.est_departure_date).to eq Date.new(2017,12,06)
      expect(shipment.departure_date).to eq Date.new(2017,12,07)
      expect(shipment.est_arrival_port_date).to eq Date.new(2018,1,27)
      expect(shipment.arrival_port_date).to eq Date.new(2018,1,28)

      expect(shipment.volume).to eq 23.87
      expect(shipment.gross_weight).to eq 2716.5
      expect(shipment.shipment_type).to eq "CY/CY"
      expect(shipment.docs_received_date).to eq Date.new(2017,12,11)
      container = shipment.containers.find {|c| c.container_number == 'ECMU1504385'}
      expect(container).not_to be_nil
      expect(container.container_size).to eq "2B"
      expect(container.seal_number).to eq "K2149159"
      
      expect(shipment.shipment_lines.length).to eq 2
      line = shipment.shipment_lines.first

      expect(line.product).to eq product
      expect(line.piece_sets.first.order_line).to eq order.order_lines.first
      expect(line.container).to eq container

      expect(line.custom_value(cdefs[:shpln_coo])).to eq "CN"
      expect(line.quantity).to eq 126
      expect(line.carton_qty).to eq 125
      expect(line.cbms).to eq 3.3
      expect(line.gross_kgs).to eq BigDecimal("365.4")
      
      expect(line.custom_value(cdefs[:shpln_invoice_number])).to eq "PK105027"
      expect(line.master_bill_of_lading).to eq "APLU067467875"
      expect(line.fcr_number).to eq "ELHJ00842SH017"
      expect(line.custom_value(cdefs[:shpln_received_date])).to eq Date.new(2017,12,1)

      expect(shipment.custom_value(cdefs[:shp_invoice_prepared])).to eq true
      expect(shipment.entity_snapshots.length).to eq 1
      s = shipment.entity_snapshots.first
      expect(s.user).to eq User.integration
      expect(s.context).to eq "file.edi"
    end

    it "replaces an existing shipment" do
      s = Factory :shipment, importer_id: ellery.id, reference: "ELLHOL-974J000427SH0", volume: 15, gross_weight: 380

      container = Factory :container, shipment: s, container_number: 'ECMU1504385', container_size: "NOT 2B"
      Factory :shipment_line, shipment: s, container: container, product: product, linked_order_line_id: order.order_lines.first, quantity: 50

      subject.parse data, bucket: "bucket", key: "file.edi"

      expect { s.reload }.to_not raise_error
      expect(Shipment.count).to eq 1
      expect(s.containers.length).to eq 1
      expect(s.shipment_lines.length).to eq 2

      c = s.containers.first
      
      # Just check for some data from the EDI to be present
      expect(s.volume).to eq 23.87
      expect(s.gross_weight).to eq 2716.5
      expect(c.container_size).to eq "2B"
      expect(c.shipment_lines.length).to eq 2
      line = s.shipment_lines.find { |sl| sl.container == c }
      expect(line.quantity).to eq 126
    end

    it "doesn't process outdated EDI" do
      s = Shipment.create!(importer_id: ellery.id, reference: "ELLHOL-974J000427SH0", last_exported_from_source: Date.new(2018, 1, 1))

      subject.parse data, bucket: "bucket", key: "file.edi"

      s = Shipment.first

      # If master bill was nil, it means nothing was processed
      expect(s.master_bill_of_lading).to be_nil
    end

    it "leaves missing port codes blank" do
      unlading.destroy

      subject.parse data, bucket: "bucket", key: "file.edi"
      expect(Shipment.first.unlading_port).to be_nil
    end
    
    it "errors if Ellery is missing" do
      ellery.destroy
      expect { subject.parse data }.to raise_error "No importer found with System Code ELLHOL."
    end

    it "errors if Order is missing" do
      order.destroy
      expect { subject.parse data }.to raise_error OpenChain::EdiParserSupport::EdiBusinessLogicError, "<br>Ellery orders are missing for the following Order Numbers:<br>60460"
    end

    it "errors if Order Line is missing" do
      order.order_lines.destroy_all

      expect { subject.parse data }.to raise_error OpenChain::EdiParserSupport::EdiBusinessLogicError, "<br>Ellery order lines are missing for the following Order / Part Number pairs:<br>60460 / 17363BEDDFULMUL<br>60460 / 17363BEDDKNGMUL"
    end

  end

end
