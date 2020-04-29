describe OpenChain::CustomHandler::Polo::PoloSystemInit do

  subject { described_class }

  describe "init" do

    let (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).and_return false
      ms
    }

    context "with Polo custom feature" do
      before :each do
        expect(master_setup).to receive(:custom_feature?).with("Polo").and_return true
      end

      it "registers Polo comparators" do
        expect(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register).with OpenChain::CustomHandler::Polo::PoloSystemClassifyProductComparator
        expect(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register).with OpenChain::CustomHandler::Polo::PoloFdaProductComparator
        expect(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register).with OpenChain::CustomHandler::Polo::PoloNonTextileProductComparator
        expect(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register).with OpenChain::CustomHandler::Polo::PoloSetTypeProductComparator
        subject.init
      end
    end

    it "does nothing" do
      expect(OpenChain::EntityCompare::ComparatorRegistry).not_to receive(:register)
      subject.init
    end

  end
end
