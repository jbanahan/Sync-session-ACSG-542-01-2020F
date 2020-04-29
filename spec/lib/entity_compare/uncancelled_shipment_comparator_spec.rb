describe OpenChain::EntityCompare::UncancelledShipmentComparator do

  let (:snapshot) {
    s = EntitySnapshot.new
    s.recordable = shipment
    s
  }

  let (:shipment) {
    Shipment.new
  }

  subject {
    Class.new {
      extend OpenChain::EntityCompare::UncancelledShipmentComparator
    }
  }

  describe "accept?" do
    it "accepts shipments that are not cancelled" do
      expect(subject.accept? snapshot).to eq true
    end

    it "rejects shipments that are cancelled" do
      shipment.canceled_date = Time.zone.now
      expect(subject.accept? snapshot).to eq false
    end

    it "rejects non-shipment snapshots" do
      s = EntitySnapshot.new
      s.recordable = Product.new
      expect(subject.accept? s).to eq false
    end
  end
end