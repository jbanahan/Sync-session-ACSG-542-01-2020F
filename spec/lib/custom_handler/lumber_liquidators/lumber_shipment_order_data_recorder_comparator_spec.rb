describe OpenChain::CustomHandler::LumberLiquidators::LumberShipmentOrderDataRecorderComparator do

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
          "shp_booking_number" => "BOOKINGNUMBER",
          "shp_cargo_ready_date" => "2018-04-01",
          "shp_booking_received_date" => "2018-04-02 12:00",
          "shp_booking_approved_date" => "2018-04-03 12:00",
          "shp_booking_confirmed_date" => "2018-04-04 12:00",
          "shp_booking_cutoff_date" => "2018-04-05 12:00"
        },
        "children" => [
          {
            "entity" => {
              "core_module" => "BookingLine",
              "record_id" => 1,
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

  let (:old_snapshot) {
    new_snapshot.deep_dup
  }

  describe "record_data" do

    let (:product) {
      Product.create! unique_identifier: "000000000010044298"
    }

    let! (:order) {
      order = Order.create! order_number: "4500230506", importer_id: Factory(:importer).id
      # Don't set anything that's not required, we want to ensure the data that's set comes from the
      # snapshot data.
      order.order_lines.create! line_number: 2, product_id: product.id
      order
    }

    it "records core order line data to order line when shipment data changes" do
      old_snapshot = new_snapshot.deep_dup
      old_snapshot["entity"]["model_fields"] = {}

      subject.record_data old_snapshot, new_snapshot

      order.reload
      expect(order.custom_value(cdefs[:ord_shipment_reference])).to eq "7ABC2FGA"
      expect(order.custom_value(cdefs[:ord_shipment_booking_number])).to eq "BOOKINGNUMBER"
      expect(order.custom_value(cdefs[:ord_shipment_cargo_ready_date])).to eq Date.new(2018, 4, 1)
      expect(order.custom_value(cdefs[:ord_shipment_booking_requested_date])).to eq Date.new(2018, 4, 2)
      expect(order.custom_value(cdefs[:ord_shipment_sent_to_carrier_date])).to eq Date.new(2018, 4, 3)
      expect(order.custom_value(cdefs[:ord_shipment_booking_confirmed_date])).to eq Date.new(2018, 4, 4)
      expect(order.custom_value(cdefs[:ord_shipment_booking_cutoff_date])).to eq Date.new(2018, 4, 5)

      # Make sure the order was snapshot'ed
      snap = order.entity_snapshots.first
      expect(snap).not_to be_nil
      expect(snap.context).to eq "Shipment Updated Data Recorder - Shipment # 7ABC2FGA"
      expect(snap.user).to eq User.integration
    end

    it "does nothing and returns if all fields are unchanged and no booking lines were added" do
      subject.record_data new_snapshot, new_snapshot

      order.reload
      expect(order.custom_value(cdefs[:ord_shipment_reference])).to be_nil
      expect(order.entity_snapshots.length).to eq 0
    end

    it "updates order data when a booking line is added, even if no shipment data changed" do
      old_snapshot = new_snapshot.deep_dup
      new_snapshot["entity"]["children"] << {
        "entity" => {
          "core_module" => "BookingLine",
          "record_id" => 2,
          "model_fields" => {
            "bkln_line_number" => 1,
            "bkln_order_line_number" => 2,
            "bkln_order_number" => "4500230506",
            "bkln_puid" => "000000000010044298"
          }
        }
      }

      subject.record_data old_snapshot, new_snapshot

      order.reload

      expect(order.custom_value(cdefs[:ord_shipment_reference])).to eq "7ABC2FGA"
      expect(order.custom_value(cdefs[:ord_shipment_booking_number])).to eq "BOOKINGNUMBER"
      expect(order.custom_value(cdefs[:ord_shipment_cargo_ready_date])).to eq Date.new(2018, 4, 1)
      expect(order.custom_value(cdefs[:ord_shipment_booking_requested_date])).to eq Date.new(2018, 4, 2)
      expect(order.custom_value(cdefs[:ord_shipment_sent_to_carrier_date])).to eq Date.new(2018, 4, 3)
      expect(order.custom_value(cdefs[:ord_shipment_booking_confirmed_date])).to eq Date.new(2018, 4, 4)
      expect(order.custom_value(cdefs[:ord_shipment_booking_cutoff_date])).to eq Date.new(2018, 4, 5)

      # Make sure the order was snapshot'ed
      snap = order.entity_snapshots.first
      expect(snap).not_to be_nil
      expect(snap.context).to eq "Shipment Updated Data Recorder - Shipment # 7ABC2FGA"
      expect(snap.user).to eq User.integration
    end

    it "does not record updates if no order data changed" do
      order.update_custom_value! cdefs[:ord_shipment_reference], "7ABC2FGA"
      order.update_custom_value! cdefs[:ord_shipment_booking_number], "BOOKINGNUMBER"
      order.update_custom_value! cdefs[:ord_shipment_cargo_ready_date], Date.new(2018, 4, 1)
      order.update_custom_value! cdefs[:ord_shipment_booking_requested_date], Date.new(2018, 4, 2)
      order.update_custom_value! cdefs[:ord_shipment_sent_to_carrier_date], Date.new(2018, 4, 3)
      order.update_custom_value! cdefs[:ord_shipment_booking_confirmed_date], Date.new(2018, 4, 4)
      order.update_custom_value! cdefs[:ord_shipment_booking_cutoff_date], Date.new(2018, 4, 5)

      expect_any_instance_of(Order).not_to receive(:save!)
      subject.record_data nil, new_snapshot
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
      s = Shipment.new
    }

    let (:snapshot) {
      EntitySnapshot.new recordable: shipment
    }

    it "accepts shipment snapshots" do
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept snapshots if they are for a cancelled shipment" do
      shipment.canceled_date = Time.zone.now
      expect(subject.accept? snapshot).to eq false
    end

  end
end