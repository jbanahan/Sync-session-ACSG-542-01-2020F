describe OpenChain::CustomHandler::LumberLiquidators::LumberShipmentRegistry do

  describe "can_uncancel?" do
    it "prevents uncancellation" do
      u = double(:user)
      s = double(:shipment)
      expect(described_class.can_uncancel?(s, u)).to eq(false)
    end
  end

  describe "cancel_shipment_hook" do
    it "deletes booking lines on cancel" do
      u = double(:user)
      s = Factory(:shipment)
      bl = Factory(:booking_line, shipment:s)
      expect(s.booking_lines.length).to eq(1)

      described_class.cancel_shipment_hook s, u

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
      expect(described_class.can_cancel? s, u).to eq true
    end

    it "returns 'true' if no canceled_date, user can edit shipment, can cancel_by_role" do
      allow(described_class).to receive(:can_cancel_as_agent?).with(s, u).and_return false
      expect(described_class.can_cancel? s, u).to eq true
    end

    it "returns 'false' if shipment has canceled_date" do
      s.update! canceled_date: Date.today
      expect(described_class.can_cancel? s, u).to eq false
    end

    it "returns 'false' if user can't edit shipment" do
      allow(s).to receive(:can_edit?).with(u).and_return false
      expect(described_class.can_cancel? s, u).to eq false
    end

    it "returns 'false' if can_cancel_as_agent and can_cancel_by_role are both false" do
      allow(s).to receive(:can_cancel_by_role?).and_return false
      allow(described_class).to receive(:can_cancel_as_agent?).with(s, u).and_return false
      expect(described_class.can_cancel? s, u).to eq false
    end

    context "can_cancel_as_agent?" do
      before do
        allow(described_class).to receive(:can_cancel_as_agent?).with(s, u).and_call_original
        allow(s).to receive(:can_cancel_by_role?).and_return false
      end

      let!(:cdef) { Factory(:custom_definition, cdef_uid: "ord_assigned_agent", data_type: :string, module_type: "Order") }
      let!(:agent_2) { Factory(:company, agent: true, system_code: "Konvenientz") }
      let!(:o1) { o = Factory(:order, order_lines: [Factory(:order_line)]); o.update_custom_value! cdef, "ACME"; o }
      let!(:o2) { o = Factory(:order, order_lines: [Factory(:order_line)]); o.update_custom_value! cdef, "ACME"; o }
      let!(:o3) { o = Factory(:order, booking_lines: [Factory(:booking_line, order_line: Factory(:order_line))]); o.update_custom_value! cdef, "ACME"; o }
      let!(:o4) { o = Factory(:order, booking_lines: [Factory(:booking_line, order_line: Factory(:order_line))]); o.update_custom_value! cdef, "ACME"; o }
      let!(:ol1) { ol = o1.order_lines.first; ol.update! order: o1; ol }
      let!(:ol2) { ol = o2.order_lines.first; ol.update! order: o2; ol }
      let!(:ol3) { ol = o3.booking_lines.first.order_line; ol.update! order: o3; ol }
      let!(:ol4) { ol = o4.booking_lines.first.order_line; ol.update! order: o4; ol }
      let!(:sl1) { sl = Factory(:shipment_line, product: ol1.product, shipment: s); sl.update! linked_order_line_id: ol1.id; sl}
      let!(:sl2) { sl = Factory(:shipment_line, product: ol2.product, shipment: s); sl.update! linked_order_line_id: ol2.id; sl}
      let!(:sl3) { sl = Factory(:shipment_line, product: ol3.product, shipment: s); sl.update! linked_order_line_id: ol3.id; sl}
      let!(:sl4) { sl = Factory(:shipment_line, product: ol4.product, shipment: s); sl.update! linked_order_line_id: ol4.id; sl}

      it "returns 'true' if all manifested and booked orders match the agent" do
        expect(described_class.can_cancel? s, u).to eq true
      end

      it "returns 'false' if any manifested orders don't match the agent" do
        o2.update_custom_value! cdef, "Konvenientz"
        expect(described_class.can_cancel? s, u).to eq false
      end

      it "returns 'false' if any booked orders don't match the agent" do
        o3.update_custom_value! cdef, "Konvenientz"
        expect(described_class.can_cancel? s, u).to eq false
      end

      it "returns 'false' if user isn't an agent" do
        u.company.update! agent: false
        expect(described_class.can_cancel? s, u).to eq false
      end

      it "returns 'false' if cdef is missing" do
        cdef.destroy
        expect(described_class.can_cancel? s, u).to eq false
      end

    end
  end
end
