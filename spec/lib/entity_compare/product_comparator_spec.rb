describe OpenChain::EntityCompare::ProductComparator do

  subject { 
    Class.new {
      extend OpenChain::EntityCompare::ProductComparator
    }
  }
  
  describe "accept?" do 

    let(:snapshot) { EntitySnapshot.new recordable_type: "Product"}

    it "accepts Product snapshots" do
      expect(subject.accept? snapshot).to eq true
    end

    it "rejects non-Product snapshots" do
      snapshot.recordable_type = "NotAProduct"
      expect(subject.accept? snapshot).to eq false
    end

  end
end
