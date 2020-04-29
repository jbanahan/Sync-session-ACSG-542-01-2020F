describe OpenChain::EntityCompare::InvoiceComparator do

  subject {
    Class.new {
      extend OpenChain::EntityCompare::InvoiceComparator
    }
  }

  describe "accept?" do

    let(:snapshot) { EntitySnapshot.new recordable_type: "Invoice"}

    it "accepts Invoice snapshots" do
      expect(subject.accept? snapshot).to eq true
    end

    it "rejects non-Invoice snapshots" do
      snapshot.recordable_type = "NotAnInvoice"
      expect(subject.accept? snapshot).to eq false
    end

  end
end