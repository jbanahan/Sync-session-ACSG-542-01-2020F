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
end