describe OpenChain::CustomHandler::Talbots::Talbots856Parser do

  let! (:talbots) { Factory(:importer, system_code: "TALBO") }
  let (:data) { IO.read 'spec/fixtures/files/talbots_856.edi'}
  let (:cdefs) { described_class.new.cdefs }

  before(:all) {
    described_class.new.cdefs
  }

  after(:all) {
    CustomDefinition.destroy_all
  }

  describe "parse", :disable_delayed_jobs do
    let (:product) {
      prod = Factory(:product, importer: talbots, unique_identifier: "TALBO-PART")
      prod.update_custom_value! cdefs[:prod_part_number], "15D2020DT"

      prod
    }

    let! (:order) {
      order = Factory(:order, importer: talbots, order_number: "TALBO-833754", customer_order_number: "833754")
      order.order_lines.create! product: product, variant: product.variants.first, sku: '15D2020DT'
      order
    }

    let! (:txg) { Factory(:port, name: "Lading", unlocode: "CNTXG")}
    let! (:nyc) { Factory(:port, name: "Entry", unlocode: "USNYC")}
    let! (:chi) { Factory(:port, name: "Final Dest", unlocode: "USCHI")}

    subject { described_class }

    it "creates a shipment" do
      subject.parse data, bucket: "bucket", key: "file.edi"

      shipment = Shipment.where(importer_id: talbots.id, reference: "TALBO-YASVTSN0039704").first
      expect(shipment).not_to be_nil
      expect(shipment.master_bill_of_lading).to eq "YASVTSN0039704"
      expect(shipment.last_file_bucket).to eq "bucket"
      expect(shipment.last_file_path).to eq "file.edi"
      expect(shipment.vessel).to eq "HOUSTON BRIDGE"
      expect(shipment.vessel_carrier_scac).to eq "YASV"
      expect(shipment.voyage).to eq "027E"
      expect(shipment.lading_port).to eq txg
      expect(shipment.entry_port).to eq nyc
      expect(shipment.inland_destination_port).to eq chi
      expect(shipment.custom_value(cdefs[:shp_invoice_prepared])).to eq true

      expect(shipment.departure_date).to eq Date.new(2017, 7, 24)
      expect(shipment.est_arrival_port_date).to eq Date.new(2017, 8, 22)
      expect(shipment.est_inland_port_date).to eq Date.new(2017, 8, 23)

      container = shipment.containers.find {|c| c.container_number == 'TCNU5516700'}
      expect(container).not_to be_nil
      expect(container.seal_number).to eq "MOL377819M"
      expect(container.size_description).to eq "45GP"

      expect(shipment.shipment_lines.length).to eq 1
      line = shipment.shipment_lines.first

      expect(line.product).to eq product
      expect(line.piece_sets.first.order_line).to eq order.order_lines.first
      expect(line.container).to eq container

      expect(line.quantity).to eq 124
      expect(line.cbms).to eq 34
      expect(line.gross_kgs).to eq BigDecimal("4674.8")
      expect(line.carton_qty).to eq 2
      expect(line.custom_value(cdefs[:shpln_coo])).to eq "CN"

      expect(shipment.entity_snapshots.length).to eq 1
      s = shipment.entity_snapshots.first
      expect(s.user).to eq User.integration
      expect(s.context).to eq "file.edi"
    end

    it "updates an existing shipment" do
      s = Shipment.create!(importer_id: talbots.id, reference: "TALBO-YASVTSN0039704")
      s.sync_records.create! trading_partner: "CI LOAD", sent_at: Time.zone.now

      container = s.containers.create! container_number: "TCNU5516700"
      line = s.shipment_lines.create! product_id: product.id, linked_order_line_id: order.order_lines.first, container_id: container.id

      container2 = s.containers.create! container_number: "CONTAINER2"
      line2 = s.shipment_lines.create! product_id: product.id, linked_order_line_id: order.order_lines.first, container_id: container2.id


      subject.parse data, bucket: "bucket", key: "file.edi"

      # The lines in the container data we received should have been destroyed...the other line should not have been touched
      s.reload
      container.reload

      # Make sure the container data was added
      expect(container.seal_number).to eq "MOL377819M"
      expect { line.reload }.to raise_error ActiveRecord::RecordNotFound
      expect { line2.reload }.not_to raise_error

      line = s.shipment_lines.find {|l| l.container == container }
      expect(line).not_to be_nil
      # Just check for some data from the EDI to be present
      expect(line.quantity).to eq 124

      # The sync record's sent at should be cleared so that the ci load will regenerate after a new file is received
      expect(s.sync_records.first.sent_at).to be_nil
    end

    it "does not process outdated EDI" do
      s = Shipment.create!(importer_id: talbots.id, reference: "TALBO-YASVTSN0039704", last_exported_from_source: Date.new(2017, 9, 1))

      subject.parse data, bucket: "bucket", key: "file.edi"

      s.reload

      # If master bill was nil, it means nothing was processed
      expect(s.master_bill_of_lading).to be_nil
    end

    it "cancels shipments" do
      s = Shipment.create!(importer_id: talbots.id, reference: "TALBO-YASVTSN0039704")
      subject.parse data.gsub("BSN^00^", "BSN^03^"), bucket: "bucket", key: "file.edi"

      s.reload
      expect(s.canceled_date).to eq ActiveSupport::TimeZone["UTC"].parse "201707251040"
      expect(s.canceled_by).to eq User.integration
    end

    it "errors if Order is missing" do
      order.destroy

      expect { subject.parse data }.to raise_error OpenChain::EdiParserSupport::EdiBusinessLogicError, "No Talbots Order found for Order # '833754'."
    end

    it "errors if an order line is missing" do
      order.order_lines.destroy_all

      expect { subject.parse data }.to raise_error OpenChain::EdiParserSupport::EdiBusinessLogicError, "No order line found on Order # '833754' with a Sku of '15D2020DT'."
    end

    it "errors if Talbots is missing" do
      talbots.destroy

      expect { subject.parse data }.to raise_error "No importer found with system code TALBO."
    end
  end
end