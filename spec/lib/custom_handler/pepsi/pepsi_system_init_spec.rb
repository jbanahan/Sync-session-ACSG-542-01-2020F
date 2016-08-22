require 'spec_helper'

describe OpenChain::CustomHandler::Pepsi::PepsiSystemInit do
  describe '#init' do
    before :each do
      allow(OpenChain::EntityCompare::ComparatorRegistry).to receive(:register)
    end
    it 'should not do anything if system_code != pepsi || pepsitest' do
      allow_any_instance_of(MasterSetup).to receive(:system_code).and_return('x')
      expect(OpenChain::EntityCompare::ComparatorRegistry).not_to receive(:register)
      OpenChain::CustomHandler::Pepsi::PepsiSystemInit.init
    end
    context 'with system code' do
      before(:each) do
        allow_any_instance_of(MasterSetup).to receive(:system_code).and_return('pepsi')
      end

      it 'should register change comparators' do
        cr = OpenChain::EntityCompare::ComparatorRegistry
        expect(cr).to receive(:register).with(OpenChain::CustomHandler::Pepsi::PepsiQuakerProductApprovalResetComparator)
        OpenChain::CustomHandler::Pepsi::PepsiSystemInit.init
      end
    end
  end
end
