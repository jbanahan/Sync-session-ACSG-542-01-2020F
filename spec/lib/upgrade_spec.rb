require 'spec_helper'

describe OpenChain::Upgrade do
  describe 'upgrade if needed' do
    it 'should run upgrade if need_upgrade? returns true' do
      MasterSetup.should_receive(:need_upgrade?).and_return(true)
      MasterSetup.any_instance.should_receive(:target_version).at_least(1).times.and_return('x')
      OpenChain::Upgrade.should_receive(:upgrade).with('x')

      OpenChain::Upgrade.upgrade_if_needed
    end
    it 'should not run upgrade if need_upgrade returns false' do
      MasterSetup.should_receive(:need_upgrade?).and_return(false)
      OpenChain::Upgrade.should_not_receive(:upgrade)

      OpenChain::Upgrade.upgrade_if_needed
    end
  end
end
