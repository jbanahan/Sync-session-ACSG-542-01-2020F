describe OpenChain::EntityCompare::MultiClassComparator do
  subject do
    Class.new { extend OpenChain::EntityCompare::MultiClassComparator.includes("Entry", "Order") }    
  end

  describe "accept?" do 
    let(:snapshot) { Factory(:entity_snapshot) }

    it "accepts Entry, Order, Product, Shipment snapshots" do
      snapshot.update_attributes! recordable: Factory(:entry)
      expect(subject.accept? snapshot).to eq true

      snapshot.update_attributes! recordable: Factory(:order)
      expect(subject.accept? snapshot).to eq true
    end

    it "rejects other snapshots" do
      snapshot.recordable_type = Factory(:broker_invoice)
      expect(subject.accept? snapshot).to eq false
    end

  end
end
