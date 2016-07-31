require 'spec_helper'

describe OpenChain::CustomHandler::Masterbrand::MasterbrandSystemInit do
  describe '#init' do
    before :each do
      OpenChain::EntityCompare::ComparatorRegistry.stub(:register)
    end
    it 'should not do anything if system_code != mbci' do
      MasterSetup.any_instance.stub(:system_code).and_return('x')
      OpenChain::EntityCompare::ComparatorRegistry.should_not_receive(:register)
      OpenChain::CustomHandler::Masterbrand::MasterbrandSystemInit.init
    end
    context 'with system code' do
      before(:each) do
        MasterSetup.any_instance.stub(:system_code).and_return('mbci')
      end
      it 'should register change comparators' do
        cr = OpenChain::EntityCompare::ComparatorRegistry
        cr.should_receive(:register).with(OpenChain::BillingComparators::EntryComparator)
        OpenChain::CustomHandler::Masterbrand::MasterbrandSystemInit.init
      end
    end
  end
end
