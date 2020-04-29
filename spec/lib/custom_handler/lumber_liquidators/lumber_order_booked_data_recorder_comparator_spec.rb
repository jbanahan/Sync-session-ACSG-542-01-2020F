describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderBookedDataRecorderComparator do

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
          "shp_booking_received_date" => "2018-04-01 12:00"
        },
        "children" => [
          {
            "entity" => {
              "core_module" => "BookingLine",
              "model_fields" => {
                "bkln_line_number" => 1,
                "bkln_order_line_number" => 2,
                "bkln_order_number" => "4500230506",
                "bkln_puid" => "000000000010044298"
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

  describe "record_data" do
    it "records core order line data to order line and returns true if lines added" do
      order
      subject.record_data nil, new_snapshot

      order.reload
      line = order.order_lines.first
      expect(line.custom_value(cdefs[:ordln_po_booked_article])).to eq "000000000010044298"
      expect(line.custom_value(cdefs[:ordln_po_booked_quantity])).to eq BigDecimal("30234.6")
      expect(line.custom_value(cdefs[:ordln_po_booked_hts])).to eq "1234567890"
      expect(line.custom_value(cdefs[:ordln_po_booked_price_per_unit])).to eq BigDecimal("0.7")
      expect(line.custom_value(cdefs[:ordln_po_booked_total_price])).to eq BigDecimal("21164.22")
      expect(line.custom_value(cdefs[:ordln_po_booked_country_origin])).to eq "CN"

      # Make sure the order was snapshot'ed
      snap = order.entity_snapshots.first
      expect(snap).not_to be_nil
      expect(snap.context).to eq "PO Booked Data Recorder - Shipment # 7ABC2FGA"
      expect(snap.user).to eq User.integration
    end

    it "does nothing and returns if booking received date is unchanged" do
      order
      subject.record_data new_snapshot, new_snapshot

      order.reload
      line = order.order_lines.first
      expect(line.custom_value(cdefs[:ordln_po_booked_article])).to be_nil
      expect(order.entity_snapshots.length).to eq 0
    end
  end


  describe "compare" do

    subject { described_class }

    it "calls through to the record_data method after retrieving the json hashes" do
      old_hash = {old: "hash"}
      new_hash = {new: "hash"}
      expect_any_instance_of(described_class).to receive(:get_json_hash).with("old-bucket", "old-path", "old-version").and_return old_hash
      expect_any_instance_of(described_class).to receive(:get_json_hash).with("new-bucket", "new-path", "new-version").and_return new_hash
      expect_any_instance_of(described_class).to receive(:record_data).with(old_hash, new_hash)

      subject.compare nil, nil, "old-bucket", "old-path", "old-version", "new-bucket", "new-path", "new-version"
    end
  end

  describe "accept?" do

    subject { described_class }

    let (:shipment) {
      s = Shipment.new booking_received_date: Time.zone.now
    }

    let (:snapshot) {
      EntitySnapshot.new recordable: shipment
    }

    it "accepts shipment snapshots if they have a booking received date" do
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept snapshots if they do not have a booking received date" do
      shipment.booking_received_date = nil
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept snapshots if they are for a cancelled shipment" do
      shipment.canceled_date = Time.zone.now
      expect(subject.accept? snapshot).to eq false
    end

  end
end