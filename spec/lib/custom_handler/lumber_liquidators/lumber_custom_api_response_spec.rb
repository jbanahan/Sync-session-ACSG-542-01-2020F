describe OpenChain::CustomHandler::LumberLiquidators::LumberCustomApiResponse do

  subject { described_class }

  describe "customize_order_response" do
    let (:order) { Order.new }
    let (:user) { User.new }
    let (:hash) { {id: nil} }
    let (:params) { {} }
    let! (:us) { FactoryBot(:country, iso_code: "US") }

    it "adds Carb and Lacey statements" do
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator).to receive(:carb_statement).with(order).and_return "carb statement"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator).to receive(:lacey_statement).with(order).and_return "lacey statement"

      hash = {id: nil}
      subject.customize_order_response order, user, hash, params

      expect(hash).to include({"carb" => "carb statement"})
      expect(hash).to include({"lacey" => "lacey statement"})
      expect(hash).to include({"us_country_id" => us.id})
    end
  end

  describe "customize_shipment_response" do
    let (:shipment) do
      s = Shipment.new
      s.containers.build container_number: "12345"
      s
    end
    let (:user) { User.new }
    let (:hash) { {"id" => nil, "containers" => [{"con_container_number" => "12345"}] } }
    let (:params) { {} }

    it "adds custom attributes" do
      # By default, all of the custom checks are going to be false, since there's no data filled in, there's
      # specific methods / test for each field, the specifics of which are tested there
      subject.customize_shipment_response(shipment, user, hash, params)

      expect(hash["custom"]["valid_delivery_location"]).to eq true
      expect(hash["custom"]["valid_master_bill"]).to eq true
      expect(hash["custom"]["can_send_factory_pack"]).to eq false
      expect(hash["custom"]["can_resend_factory_pack"]).to eq false
      expect(hash["custom"]["can_send_vgm"]).to eq false
      expect(hash["custom"]["can_resend_vgm"]).to eq false
      expect(hash["custom"]["can_send_isf"]).to eq false
      expect(hash["custom"]["can_resend_isf"]).to eq false

      expect(hash["containers"].first["custom"]["has_all_vgm_data"]).to be false
    end

    it "returns false for can_* permissions if user cannot edit shipment" do
      expect(shipment).to receive(:can_edit?).with(user).and_return false
      # None of these methods should be called because the can_edit? false short circuits their method calls
      expect(subject).not_to receive(:can_send_factory_pack?)
      expect(subject).not_to receive(:can_send_vgm?)
      expect(subject).not_to receive(:can_send_isf?)
      subject.customize_shipment_response(shipment, user, hash, params)

      expect(hash["custom"]["can_send_factory_pack"]).to eq false
      expect(hash["custom"]["can_resend_factory_pack"]).to eq false
      expect(hash["custom"]["can_send_vgm"]).to eq false
      expect(hash["custom"]["can_resend_vgm"]).to eq false
      expect(hash["custom"]["can_send_isf"]).to eq false
      expect(hash["custom"]["can_resend_isf"]).to eq false
    end

    it "doesn't check delivery location if it's not set" do
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberOrderBooking).not_to receive(:valid_delivery_location?)
      subject.customize_shipment_response(shipment, user, hash, params)
      expect(hash["custom"]["valid_delivery_location"]).to eq true
    end

    it "adds invalid_delivery_location" do
      shipment.first_port_receipt_id = 1
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberOrderBooking).to receive(:valid_delivery_location?).with(shipment).and_return false
      subject.customize_shipment_response(shipment, user, hash, params)
      expect(hash["custom"]["valid_delivery_location"]).to eq false
    end

    it "shows master bill warning when house bill set, master bill blank and mbol unknown flag not checked" do
      shipment.master_bill_of_lading = " "
      shipment.house_bill_of_lading = "XYZA16286286"
      cdefs = described_class.custom_definitions([:shp_master_bol_unknown])
      shipment.find_and_set_custom_value(cdefs[:shp_master_bol_unknown], false)

      subject.customize_shipment_response(shipment, user, hash, params)
      expect(hash["custom"]["valid_master_bill"]).to eq false
    end

    it "does not show master bill warning when house bill set, master bill blank and mbol unknown flag is checked" do
      shipment.master_bill_of_lading = " "
      shipment.house_bill_of_lading = "XYZA16286286"
      cdefs = described_class.custom_definitions([:shp_master_bol_unknown])
      shipment.find_and_set_custom_value(cdefs[:shp_master_bol_unknown], true)

      subject.customize_shipment_response(shipment, user, hash, params)
      expect(hash["custom"]["valid_master_bill"]).to eq true
    end
  end

  describe "can_send_factory_pack?" do

    let (:container) do
      shipment.containers.first
    end

    let (:line) do
      shipment.shipment_lines.first
    end

    let (:shipment) do
      # by default, make a shipment that can be sent...
      s = Shipment.new vendor_id: 1, booking_number: "BOOK", booking_vessel: "VESS", booking_voyage: "VOY", importer_reference: "REF"
      s.containers.build container_number: "12345", container_size: "40HC", seal_number: "ARF"
      s.shipment_lines.build quantity: 1, carton_qty: 2, cbms: 3, gross_kgs: 4
      s
    end

    it "validates presence of all data required to send factory pack document" do
      expect(subject.can_send_factory_pack?(shipment, false)).to eq true
    end

    context "with missing fields" do
      it "returns false if factory pack already sent" do
        shipment.packing_list_sent_date = Time.zone.now
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if vendor is missing" do
        shipment.vendor_id = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if booking number is missing" do
        shipment.booking_number = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if booking vessel is missing" do
        shipment.booking_vessel = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if booking voyage is missing" do
        shipment.booking_voyage = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if importer reference is missing" do
        shipment.importer_reference = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if container number is missing" do
        container.container_number = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if container size is missing" do
        container.container_size = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if container seal number is missing" do
        container.seal_number = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if line quantity is missing" do
        line.quantity = 0
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if line carton quantity is missing" do
        line.carton_qty = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if line volume is missing" do
        line.cbms = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if line weight is missing" do
        line.gross_kgs = nil
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "retuns false if there are no shipment lines" do
        shipment.shipment_lines = []
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end

      it "returns false if there are no containers" do
        shipment.containers = []
        expect(subject.can_send_factory_pack?(shipment, false)).to eq false
      end
    end

    it "allows resend if already sent" do
      shipment.packing_list_sent_date = Time.zone.now
      expect(subject.can_send_factory_pack?(shipment, true)).to eq true
    end

    it "disallows resend if not already sent" do
      expect(subject.can_send_factory_pack?(shipment, true)).to eq false
    end
  end

  describe "can_send_isf?" do
    let (:line) do
      shipment.shipment_lines.first
    end

    let (:shipment) do
      # by default, make a shipment that can be sent...
      # Note that it does not have house bill set.  House bill is only required when master is not provided.
      # That is tested in more detail below.
      s = Shipment.new booking_number: "BOOK", vessel: "VESS", voyage: "VOY", master_bill_of_lading: "MBOL", est_departure_date: Time.zone.now,
                       seller_address_id: 1, ship_to_address_id: 1, ship_from_id: 1, consolidator_address_id: 1, container_stuffing_address_id: 1, country_origin_id: 1
      s.shipment_lines.build quantity: 1, carton_qty: 2, cbms: 3, gross_kgs: 4
      s
    end

    it "validates presence of all data required to send isf document" do
      expect(subject.can_send_isf?(shipment, false)).to eq true
    end

    context "with missing fields" do
      it "returns false if booking number is missing" do
        shipment.booking_number = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if vessel is missing" do
        shipment.vessel = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if voyage is missing" do
        shipment.voyage = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if master_bill_of_lading and house_bill_of_lading are missing" do
        shipment.master_bill_of_lading = nil
        shipment.house_bill_of_lading = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if master_bill_of_lading is missing, house bill is present and mbol unknown not checked" do
        shipment.master_bill_of_lading = nil
        shipment.house_bill_of_lading = "XYZA16286286"
        cdefs = described_class.custom_definitions([:shp_master_bol_unknown])
        shipment.find_and_set_custom_value(cdefs[:shp_master_bol_unknown], false)
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if est departure is missing" do
        shipment.est_departure_date = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if seller is missing" do
        shipment.seller_address_id = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if ship to is missing" do
        shipment.ship_to_address_id = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if ship_from is missing" do
        shipment.ship_from_id = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if consolidator is missing" do
        shipment.consolidator_address_id = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if container_stuffing is missing" do
        shipment.container_stuffing_address_id = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if country of origin is missing" do
        shipment.country_origin_id = nil
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end

      it "returns false if no shipment lines" do
        shipment.shipment_lines.clear
        expect(subject.can_send_isf?(shipment, false)).to eq false
      end
    end

    it "allows resend if already sent" do
      shipment.isf_sent_at = Time.zone.now
      expect(subject.can_send_isf?(shipment, true)).to eq true
    end

    it "disallows resend if not already sent" do
      expect(subject.can_send_isf?(shipment, true)).to eq false
    end

    it "allows send if master_bill_of_lading is missing, but house bill is present and mbol unknown is checked" do
      shipment.master_bill_of_lading = nil
      shipment.house_bill_of_lading = "XYZA16286286"
      cdefs = described_class.custom_definitions([:shp_master_bol_unknown])
      shipment.find_and_set_custom_value(cdefs[:shp_master_bol_unknown], true)
      expect(subject.can_send_isf?(shipment, false)).to eq true
    end
  end

  describe "can_send_vgm?" do
    let (:cdefs) do
      described_class.custom_definitions([:con_weighed_date, :con_weighing_method,
                                          :con_total_vgm_weight, :con_cargo_weight,
                                          :con_dunnage_weight, :con_tare_weight])
    end

    let (:container) do
      c = shipment.containers.build container_number: "12345", container_size: "40HC", seal_number: "ARF"
      c.find_and_set_custom_value(cdefs[:con_weighed_date], Time.zone.now)
      c.find_and_set_custom_value(cdefs[:con_weighing_method], 2)
      c.find_and_set_custom_value(cdefs[:con_total_vgm_weight], 1)
      c.find_and_set_custom_value(cdefs[:con_cargo_weight], 3)
      c.find_and_set_custom_value(cdefs[:con_dunnage_weight], 4)
      c.find_and_set_custom_value(cdefs[:con_tare_weight], 4)

      c
    end

    let (:line) do
      shipment.shipment_lines.first
    end

    let (:shipment) do
      # by default, make a shipment that can be sent...
      s = Shipment.new vendor_id: 1, booking_number: "BOOK"
      s.shipment_lines.build quantity: 1, carton_qty: 2, cbms: 3, gross_kgs: 4
      s
    end

    before do
      container
    end

    it "validates presence of all data required to send vgm document" do
      expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq true
    end

    context "with missing fields" do
      it "returns false if vendor is missing" do
        shipment.vendor_id = nil
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
      end

      it "returns false if booking number is missing" do
        shipment.booking_number = nil
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
      end

      it "returns false if container number is missing" do
        container.container_number = nil
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
      end

      it "returns false if weighed date is missing" do
        container.find_and_set_custom_value(cdefs[:con_weighed_date], nil)
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
      end

      it "returns false if weighing method is missing" do
        container.find_and_set_custom_value(cdefs[:con_weighing_method], nil)
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
      end

      it "returns false if total vgm weight is missing" do
        container.find_and_set_custom_value(cdefs[:con_total_vgm_weight], nil)
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
      end

      it "retuns false if there are no shipment lines" do
        shipment.shipment_lines = []
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
      end

      it "returns false if there are no containers" do
        shipment.containers = []
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
      end

      context "with weighing method == 2" do
        before { container.find_and_set_custom_value(cdefs[:con_weighing_method], 2) }

        it "returns false if cargo weight is missing" do
          container.find_and_set_custom_value(cdefs[:con_cargo_weight], nil)
          expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
        end

        it "returns false if dunnage weight is missing" do
          container.find_and_set_custom_value(cdefs[:con_dunnage_weight], nil)
          expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
        end

        it "returns false if tare weight is missing" do
          container.find_and_set_custom_value(cdefs[:con_tare_weight], nil)
          expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq false
        end
      end
    end

    context "with weighing method == 1" do
      before { container.find_and_set_custom_value(cdefs[:con_weighing_method], 1) }

      it "returns true if cargo weight is missing" do
        container.find_and_set_custom_value(cdefs[:con_cargo_weight], nil)
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq true
      end

      it "returns true if dunnage weight is missing" do
        container.find_and_set_custom_value(cdefs[:con_dunnage_weight], nil)
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq true
      end

      it "returns true if tare weight is missing" do
        container.find_and_set_custom_value(cdefs[:con_tare_weight], nil)
        expect(subject.can_send_vgm?(shipment, false, cdefs)).to eq true
      end
    end

    it "allows resend if already sent" do
      shipment.vgm_sent_date = Time.zone.now
      expect(subject.can_send_vgm?(shipment, true, cdefs)).to eq true
    end

    it "disallows resend if not already sent" do
      expect(subject.can_send_vgm?(shipment, true, cdefs)).to eq false
    end

  end
end
