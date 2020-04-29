describe OpenChain::CustomHandler::Masterbrand::MasterbrandSystemInit do
  subject { described_class }

  describe 'init' do
    let! (:ms) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("MBCI").and_return false
      ms
    }

    it 'should not do anything if custom feature is not enabled' do
      expect(OpenChain::EntityCompare::ComparatorRegistry).not_to receive(:register)
      subject.init
    end

    context 'with custom feature' do
      let! (:ms) {
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("MBCI").and_return true
        ms
      }

      it 'should register change comparators' do
        expect(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register).with(OpenChain::BillingComparators::EntryComparator)
        subject.init
      end
    end
  end
end
