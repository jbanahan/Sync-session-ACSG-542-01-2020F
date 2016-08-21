require 'spec_helper'
require 'fileutils'

describe OpenChain::Upgrade do
  describe 'upgrade if needed' do
    it 'should run upgrade if need_upgrade? returns true' do
      expect(MasterSetup).to receive(:need_upgrade?).and_return(true)
      expect_any_instance_of(MasterSetup).to receive(:target_version).at_least(1).times.and_return('x')
      expect(OpenChain::Upgrade).to receive(:upgrade).with('x', false, {})

      OpenChain::Upgrade.upgrade_if_needed
    end
    it 'should not run upgrade if need_upgrade returns false' do
      expect(MasterSetup).to receive(:need_upgrade?).and_return(false)
      expect(OpenChain::Upgrade).not_to receive(:upgrade)

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
        expect(OpenChain::Upgrade.in_progress?).to be_truthy
      end  
    end
    
    it "should report no upgrade in progress if upgrade file is missing" do
      expect(OpenChain::Upgrade.in_progress?).to be_falsey
    end
  end

  context :errored? do
    after :each do
      FileUtils.rm('tmp/upgrade_error.txt') if File.exist?('tmp/upgrade_error.txt')
    end

    it "should report upgrade errors if the file is present" do
      FileUtils.touch 'tmp/upgrade_error.txt'
      expect(OpenChain::Upgrade.errored?).to be_truthy
    end

    it "should not report upgrade errors if the file is not present" do
      expect(OpenChain::Upgrade.errored?).to be_falsey
    end
    
  end
end
