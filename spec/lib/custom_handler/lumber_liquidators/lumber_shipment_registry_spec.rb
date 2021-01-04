describe OpenChain::CustomHandler::LumberLiquidators::LumberShipmentRegistry do

  describe "save_shipment_hook" do
    let(:cdefs) { described_class.custom_definitions([:shp_master_bol_unknown]) }
    let(:s) { Factory(:shipment) }

    it "clears MBOL unknown when master bill is provided" do
      s.master_bill_of_lading = "isjedgjisjh"
      s.find_and_set_custom_value cdefs[:shp_master_bol_unknown], true
      described_class.save_shipment_hook(s, nil)

      expect(s.custom_value(cdefs[:shp_master_bol_unknown])).to eq false
    end

    it "does not clear MBOL unknown when master bill is blank" do
      s.master_bill_of_lading = " "
      s.find_and_set_custom_value cdefs[:shp_master_bol_unknown], true
      described_class.save_shipment_hook(s, nil)

      expect(s.custom_value(cdefs[:shp_master_bol_unknown])).to eq true
    end
  end

  describe "can_uncancel?" do
    it "prevents uncancellation" do
      s = Factory(:shipment)
      expect(described_class.can_uncancel?(s, "user")).to eq(false)
    end
  end

  describe "cancel_shipment_hook" do
    it "deletes booking lines on cancel" do
      s = Factory(:shipment)
      Factory(:booking_line, shipment: s)
      expect(s.booking_lines.length).to eq(1)

      described_class.cancel_shipment_hook s, "user"

      s.reload
      expect(s.booking_lines.length).to eq(0)
    end
  end

  describe "can_cancel?" do
    let(:imp) { Factory(:company, system_code: "ACME", agent: true) }
    let(:u) { Factory(:user, company: imp) }
    let(:s) { Factory(:shipment, canceled_date: nil, importer: imp) }

    before do
      allow(s).to receive(:can_edit?).with(u).and_return true
      allow(s).to receive(:can_cancel_by_role?).with(u).and_return true
      allow(described_class).to receive(:can_cancel_as_agent?).with(s, u).and_return true
    end

    it "returns 'true' if no canceled_date, user can edit shipment, can cancel_as_agent" do
      allow(s).to receive(:can_cancel_by_role?).and_return false
      expect(described_class.can_cancel?(s, u)).to eq true
    end

    it "returns 'true' if no canceled_date, user can edit shipment, can cancel_by_role" do
      allow(described_class).to receive(:can_cancel_as_agent?).with(s, u).and_return false
      expect(described_class.can_cancel?(s, u)).to eq true
    end

    it "returns 'false' if shipment has canceled_date" do
      s.update! canceled_date: Time.zone.today
      expect(described_class.can_cancel?(s, u)).to eq false
    end

    it "returns 'false' if user can't edit shipment" do
      allow(s).to receive(:can_edit?).with(u).and_return false
      expect(described_class.can_cancel?(s, u)).to eq false
    end

    it "returns 'false' if can_cancel_as_agent and can_cancel_by_role are both false" do
      allow(s).to receive(:can_cancel_by_role?).and_return false
      allow(described_class).to receive(:can_cancel_as_agent?).with(s, u).and_return false
      expect(described_class.can_cancel?(s, u)).to eq false
    end

    context "can_cancel_as_agent?" do
      before do
        allow(described_class).to receive(:can_cancel_as_agent?).with(s, u).and_call_original
        allow(s).to receive(:can_cancel_by_role?).and_return false

        Factory(:company, agent: true, system_code: "Konvenientz")

        o1 = Factory(:order, order_lines: [Factory(:order_line)])
        o1.update_custom_value! cdef, "ACME"
        ol = o1.order_lines.first
        ol.update! order: o1
        sl = Factory(:shipment_line, product: ol.product, shipment: s)
        sl.update! linked_order_line_id: ol.id

        o4 = Factory(:order, booking_lines: [Factory(:booking_line, order_line: Factory(:order_line))])
        o4.update_custom_value! cdef, "ACME"
        ol = o4.booking_lines.first.order_line
        ol.update! order: o4
        sl = Factory(:shipment_line, product: ol.product, shipment: s)
        sl.update! linked_order_line_id: ol.id
      end

      let!(:cdef) { Factory(:custom_definition, cdef_uid: "ord_assigned_agent", data_type: :string, module_type: "Order") }
      let!(:o2) do
        o = Factory(:order, order_lines: [Factory(:order_line)])
        o.update_custom_value! cdef, "ACME"
        ol = o.order_lines.first
        ol.update! order: o
        sl = Factory(:shipment_line, product: ol.product, shipment: s)
        sl.update! linked_order_line_id: ol.id
        o
      end
      let!(:o3) do
        o = Factory(:order, booking_lines: [Factory(:booking_line, order_line: Factory(:order_line))])
        o.update_custom_value! cdef, "ACME"
        ol = o.booking_lines.first.order_line
        ol.update! order: o
        sl = Factory(:shipment_line, product: ol.product, shipment: s)
        sl.update! linked_order_line_id: ol.id
        o
      end

      it "returns 'true' if all manifested and booked orders match the agent" do
        expect(described_class.can_cancel?(s, u)).to eq true
      end

      it "returns 'false' if any manifested orders don't match the agent" do
        o2.update_custom_value! cdef, "Konvenientz"
        expect(described_class.can_cancel?(s, u)).to eq false
      end

      it "returns 'false' if any booked orders don't match the agent" do
        o3.update_custom_value! cdef, "Konvenientz"
        expect(described_class.can_cancel?(s, u)).to eq false
      end

      it "returns 'false' if user isn't an agent" do
        u.company.update! agent: false
        expect(described_class.can_cancel?(s, u)).to eq false
      end

      it "returns 'false' if cdef is missing" do
        cdef.destroy
        expect(described_class.can_cancel?(s, u)).to eq false
      end

    end
  end
end
