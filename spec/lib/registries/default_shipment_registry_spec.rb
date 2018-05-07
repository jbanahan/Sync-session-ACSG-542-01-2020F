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