describe OpenChain::CustomHandler::Target::TargetSystemInit do

  subject { described_class }

  describe 'init' do
    let! (:ms) do
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("Target").and_return false
      ms
    end

    it 'does not do anything if custom feature is not enabled' do
      expect(OpenChain::EntityCompare::ComparatorRegistry).not_to receive(:register)
      subject.init
    end

    context 'with custom feature' do
      let! (:ms) do
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("Target").and_return true
        ms
      end

      it 'registers change comparators' do
        expect(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register).with(OpenChain::CustomHandler::Target::TargetEntryDocumentsComparator)
        subject.init
      end
    end
  end
end