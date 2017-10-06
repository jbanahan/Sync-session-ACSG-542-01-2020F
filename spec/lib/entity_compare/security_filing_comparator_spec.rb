describe OpenChain::EntityCompare::SecurityFilingComparator do

  subject { 
    Class.new {
      extend OpenChain::EntityCompare::SecurityFilingComparator
    }
  }
  
  describe "accept?" do 

    let(:snapshot) { EntitySnapshot.new recordable_type: "SecurityFiling"}

    it "accepts SecurityFiling snapshots" do
      expect(subject.accept? snapshot).to eq true
    end

    it "rejects non-SecurityFiling snapshots" do
      snapshot.recordable_type = "NotASecurityFiling"
      expect(subject.accept? snapshot).to eq false
    end

  end
end