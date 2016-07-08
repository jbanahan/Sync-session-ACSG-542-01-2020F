require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit do
  describe '#init' do
    before :each do
      OpenChain::CustomHandler::CustomViewSelector.stub(:register_handler)
      OpenChain::EntityCompare::ComparatorRegistry.stub(:register)
    end
    it 'should not do anything if system_code != ll' do
      MasterSetup.any_instance.stub(:system_code).and_return('x')
      OpenChain::CustomHandler::CustomViewSelector.should_not_receive(:register_handler)
      OpenChain::EntityCompare::ComparatorRegistry.should_not_receive(:register)
      OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
    end
    context 'with system code' do
      before(:each) do
        MasterSetup.any_instance.stub(:system_code).and_return('ll')
      end
      it 'should call custom view selector' do
        OpenChain::CustomHandler::CustomViewSelector.
          should_receive(:register_handler).
          with(OpenChain::CustomHandler::LumberLiquidators::LumberViewSelector)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end
      it 'should register change comparators' do
        cr = OpenChain::EntityCompare::ComparatorRegistry
        cr.should_receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator)
        cr.should_receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorAssignmentChangeComparator)
        cr.should_receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberProductChangeComparator)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end
      it 'should register order acceptance' do
        oar = OpenChain::OrderAcceptanceRegistry
        oar.should_receive(:register).with(OpenChain::CustomHandler::LumberLiquidators::LumberOrderAcceptance)
        OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init
      end

    end
  end
end
