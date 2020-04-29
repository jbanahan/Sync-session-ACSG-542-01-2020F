describe OpenChain::Registries::DefaultShipmentRegistry do

  describe "can_cancel?" do
    it "should allow if shipment does not have canceled date and user is allowed to cancel and edit shipments" do
      u = double(:user)
      s = Shipment.new(canceled_date:nil)
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s).to receive(:can_cancel_by_role?).with(u).and_return true
      expect(described_class.can_cancel?(s, u)).to be_truthy
    end

    it "should not allow if user cannot edit shipments" do
      u = double(:user)
      s = Shipment.new(canceled_date:nil)
      allow(s).to receive(:can_cancel_by_role?).and_return true
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(described_class.can_cancel?(s, u)).to be_falsey
    end

    it "should not allow if user cannot cancel shipments" do
      u = double(:user)
      s = Shipment.new(canceled_date:nil)
      allow(s).to receive(:can_edit?).and_return true
      expect(s).to receive(:can_cancel_by_role?).with(u).and_return false
      expect(described_class.can_cancel?(s, u)).to be_falsey
    end

    it "should not allow if shipment has canceled date" do
      u = double(:user)
      s = Shipment.new(canceled_date:Time.now)
      allow(s).to receive(:can_edit?).and_return true
      allow(s).to receive(:can_cancel_by_role?).and_return true
      expect(described_class.can_cancel?(s, u)).to be_falsey
    end

    # tests code located in shipment.rb
    context "can_cancel_by_role?" do
      let(:imp) { Factory(:company, system_code: "ACME", agent: true) }
      let(:u) { Factory(:user, company: imp) }
      let(:s) { Factory(:shipment, canceled_date: nil, importer: imp) }
      before do
        allow(s).to receive(:can_edit?).with(u).and_return true
        allow(s).to receive(:can_cancel_as_vendor?).with(u).and_return false
        allow(s).to receive(:can_cancel_as_importer?).with(u).and_return false
        allow(s).to receive(:can_cancel_as_carrier?).with(u).and_return false
        allow(s).to receive(:can_cancel_as_agent?).with(u).and_return false
      end

      it "returns 'true' for master user" do
        imp.update! master: true
        expect(s.can_cancel_by_role?(u)).to eq true
      end

      # This really ought to also have sections for #can_cancel_as_vendor?, #can_cancel_as_importer?, #can_cancel_as_carrier?
      context "can_cancel_as_agent?" do
        let!(:agent_2) { Factory(:company, agent: true, system_code: "Konvenientz") }
        let!(:o1) { Factory(:order, agent: imp, order_lines: [Factory(:order_line)]) }
        let!(:o2) { Factory(:order, agent: imp, order_lines: [Factory(:order_line)]) }
        let!(:o3) { Factory(:order, agent: imp, booking_lines: [Factory(:booking_line, order_line: Factory(:order_line))]) }
        let!(:o4) { Factory(:order, agent: imp, booking_lines: [Factory(:booking_line, order_line: Factory(:order_line))]) }
        let!(:ol1) { ol = o1.order_lines.first; ol.update! order: o1; ol }
        let!(:ol2) { ol = o2.order_lines.first; ol.update! order: o2; ol }
        let!(:ol3) { ol = o3.booking_lines.first.order_line; ol.update! order: o3; ol }
        let!(:ol4) { ol = o4.booking_lines.first.order_line; ol.update! order: o4; ol }
        let!(:sl1) { sl = Factory(:shipment_line, product: ol1.product, shipment: s); sl.update! linked_order_line_id: ol1.id; sl}
        let!(:sl2) { sl = Factory(:shipment_line, product: ol2.product, shipment: s); sl.update! linked_order_line_id: ol2.id; sl}
        let!(:sl3) { sl = Factory(:shipment_line, product: ol3.product, shipment: s); sl.update! linked_order_line_id: ol3.id; sl}
        let!(:sl4) { sl = Factory(:shipment_line, product: ol4.product, shipment: s); sl.update! linked_order_line_id: ol4.id; sl}


        before do
          allow(s).to receive(:can_cancel_as_agent?).with(u).and_call_original
          u.company.update! agent: true
        end

        it "returns 'true' if all manifested and booked orders match the agent" do
          expect(s.can_cancel_by_role?(u)).to eq true
        end

        it "returns 'false' if any manifested orders don't match the agent" do
          o2.agent = agent_2; o2.save!
          expect(s.can_cancel_by_role?(u)).to eq false
        end

        it "returns 'false' if any booked orders don't match the agent" do
          o3.agent = agent_2; o3.save!
          expect(s.can_cancel_by_role?(u)).to eq false
        end

        it "returns 'false' if user isn't an agent" do
          u.company.update! agent: false
          expect(described_class.can_cancel? s, u).to eq false
        end
      end

    end
  end

  describe "can_uncancel?" do
    it "should allow if shipment has canceled date and user is allowed to cancel and edit shipments" do
      u = double(:user)
      s = Shipment.new(canceled_date:Time.now)
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s).to receive(:can_cancel_by_role?).with(u).and_return true
      expect(described_class.can_uncancel?(s, u)).to be_truthy
    end

    it "should not allow if user cannot edit shipments" do
      u = double(:user)
      s = Shipment.new(canceled_date:Time.now)
      allow(s).to receive(:can_cancel_by_role?).and_return true
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(described_class.can_uncancel?(s, u)).to be_falsey
    end

    it "should not allow if user cannot cancel shipments" do
      u = double(:user)
      s = Shipment.new(canceled_date:Time.now)
      allow(s).to receive(:can_edit?).and_return true
      expect(s).to receive(:can_cancel_by_role?).with(u).and_return false
      expect(described_class.can_uncancel?(s, u)).to be_falsey
    end

    it "should not allow if shipment does not have canceled date" do
      u = double(:user)
      s = Shipment.new(canceled_date:nil)
      allow(s).to receive(:can_edit?).and_return true
      allow(s).to receive(:can_cancel_by_role?).and_return true
      expect(described_class.can_uncancel?(s, u)).to be_falsey
    end
  end
end
