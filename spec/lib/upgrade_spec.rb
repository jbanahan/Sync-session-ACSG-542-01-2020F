require 'spec_helper'
require 'fileutils'

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

  context :in_progress? do
    context :file_present do
      before :each do 
        FileUtils.touch 'tmp/upgrade_running.txt'
      end

      after :each do
        FileUtils.rm 'tmp/upgrade_running.txt' if File.exist? 'tmp/upgrade_running.txt'
      end

      it "should report upgrade in progress if tmp/upgrade_running.txt file is present" do  
        OpenChain::Upgrade.in_progress?.should be_true
      end  
    end
    
    it "should report no upgrade in progress if upgrade file is missing" do
      OpenChain::Upgrade.in_progress?.should be_false
    end
  end
end
