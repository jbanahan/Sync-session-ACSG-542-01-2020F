require 'spec_helper'

describe OpenChain::CustomHandler::Masterbrand::MasterbrandSystemInit do
  describe '#init' do
    before :each do
      allow(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register)
    end
    it 'should not do anything if system_code != mbci' do
      allow_any_instance_of(MasterSetup).to receive(:system_code).and_return('x')
      expect(OpenChain::EntityCompare::ComparatorRegistry).not_to receive(:register)
      OpenChain::CustomHandler::Masterbrand::MasterbrandSystemInit.init
    end
    context 'with system code' do
      before(:each) do
        allow_any_instance_of(MasterSetup).to receive(:system_code).and_return('mbci')
      end
      it 'should register change comparators' do
        cr = OpenChain::EntityCompare::ComparatorRegistry
        expect(cr).to receive(:register).with(OpenChain::BillingComparators::EntryComparator)
        OpenChain::CustomHandler::Masterbrand::MasterbrandSystemInit.init
      end
    end
  end
end
