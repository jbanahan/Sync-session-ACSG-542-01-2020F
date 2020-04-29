describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderShippedDataRecorderComparator do

  before :all do
    described_class.new.send(:cdefs)
  end

  after :all do
    CustomDefinition.destroy_all
  end

  let (:cdefs) {
    subject.send(:cdefs)
  }

  let (:new_snapshot) {
    {
      "entity" => {
        "core_module" => "Shipment",
        "model_fields" => {
          "shp_ref" => "7ABC2FGA",
          "shp_last_exported_from_source" => "2018-04-01 12:00",
          "shp_master_bill_of_lading" => "MBOL"
        },
        "children" => [
          {
            "entity" => {
              "record_id" => shipment.shipment_lines.first.id,
              "core_module" => "ShipmentLine",
              "model_fields" => {
                "shpln_line_number" => 1,
                "shpln_container_number" => "OOLU0438191"
              }
            }
          },
          {
          "entity" => {
            "core_module" => "Container",
            "model_fields" => {
              "con_container_number" => "OOLU0438191",
              "con_seal_number" => "OOLEHN2798"
              }
            }
          }
        ]
      }
    }
  }

  let (:us) {
    Country.create! iso_code: "US"
  }

  let (:product) {
    p = Product.create! unique_identifier: "000000000010044298"
    p.update_hts_for_country us, "1234567890"
    p
  }

  let (:order) {
    order = Order.create! order_number: "4500230506", importer_id: Factory(:importer).id
    order.update_custom_value! cdefs[:ord_country_of_origin], "CN"
    # Don't set anything that's not required, we want to ensure the data that's set comes from the
    # snapshot data.
    order.order_lines.create! line_number: 2, product_id: product.id, quantity: BigDecimal("30234.6"), price_per_unit: BigDecimal("0.7")
    order
  }

  let (:shipment) {
    shipment = Factory(:shipment, reference: "7ABC2FGA", importer_id: order.importer_id)
    l = shipment.shipment_lines.build
    l.quantity = 992
    l.product = product
    l.linked_order_line_id = order.order_lines.first.id
    l.save!

    shipment
  }

  describe "record_data" do

    it "records core order line data to order line" do
      subject.record_data nil, new_snapshot

      order.reload
      line = order.order_lines.first
      expect(line.custom_value(cdefs[:ordln_po_shipped_article])).to eq "000000000010044298"
      expect(line.custom_value(cdefs[:ordln_po_shipped_quantity])).to eq BigDecimal("30234.6")
      expect(line.custom_value(cdefs[:ordln_po_shipped_hts])).to eq "1234567890"
      expect(line.custom_value(cdefs[:ordln_po_shipped_price_per_unit])).to eq BigDecimal("0.7")
      expect(line.custom_value(cdefs[:ordln_po_shipped_total_price])).to eq BigDecimal("21164.22")
      expect(line.custom_value(cdefs[:ordln_po_shipped_country_origin])).to eq "CN"
      expect(line.custom_value(cdefs[:ordln_po_shipped_bol])).to eq "MBOL"
      expect(line.custom_value(cdefs[:ordln_po_shipped_container_number])).to eq "OOLU0438191"
      expect(line.custom_value(cdefs[:ordln_po_shipped_seal_number])).to eq "OOLEHN2798"

      # Make sure the order was snapshot'ed
      snap = order.entity_snapshots.first
      expect(snap).not_to be_nil
      expect(snap.context).to eq "PO Shipped Data Recorder - Shipment # 7ABC2FGA"
      expect(snap.user).to eq User.integration
    end

    it "does nothing if the last exported from source was not updated" do
      # Add a second imaginary line to the snapshot so it looks like it's going from 1 - 2
      # lines, but without the asn date updating.
      snap = new_snapshot.dup
      line = snap['entity']['children'].first.dup
      line['entity']['record_id'] = 2
      line['entity']['model_fields']['shpln_line_number'] = 2
      snap['entity']['children'] << line

      subject.record_data new_snapshot, snap

      order.reload
      line = order.order_lines.first
      expect(line.custom_value(cdefs[:ordln_po_shipped_article])).to be_nil
      expect(order.entity_snapshots.length).to eq 0
    end

    it "does not overwrite existing po shipped values on order line" do
      line = order.order_lines.first
      # This is the only field that is checked to see if the order line already has data recorded
      line.update_custom_value!(cdefs[:ordln_po_shipped_quantity], BigDecimal("1"))

      subject.record_data nil, new_snapshot

      order.reload
      line = order.order_lines.first

      expect(line.custom_value(cdefs[:ordln_po_shipped_article])).to be_nil
      expect(order.entity_snapshots.length).to eq 0
    end
  end

  describe "accept?" do

    subject { described_class }

    let (:shipment) {
      s = Shipment.new last_exported_from_source: Time.zone.now
    }

    let (:snapshot) {
      EntitySnapshot.new recordable: shipment
    }

    it "accepts shipment snapshots if they have a last exported from source date" do
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept snapshots if they do not have a last exported from source  date" do
      shipment.last_exported_from_source = nil
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept snapshots if they are for a cancelled shipment" do
      shipment.canceled_date = Time.zone.now
      expect(subject.accept? snapshot).to eq false
    end

  end
end