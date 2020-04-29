require 'fileutils'

describe OpenChain::Upgrade do
  subject { described_class.new("TARGET_VERSION") }

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

  describe "in_progress?" do
    context "file_present" do
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

  describe "errored?" do
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

  describe "send_slack_failure" do
    let (:master_setup) { stub_master_setup }
    let (:error) { StandardError.new "Error Message"}
    let (:slack) { instance_double(OpenChain::SlackClient) }

    it "forwards error message to slack" do
      expect(subject).to receive(:slack_client).and_return slack
      expect(slack).to receive(:send_message).with('it-dev-notifications', "<!group>: Upgrade failed for server: #{`hostname`.strip}, instance: #{master_setup.system_code}, error: Error Message", {icon_emoji:':loudspeaker:'})

      subject.send_slack_failure master_setup, error
    end
  end

  context "freshservice callbacks" do
    let(:freshservice) { instance_double(OpenChain::FreshserviceClient) }

    before :each do
      allow(subject).to receive(:freshservice_client).and_return freshservice
    end

    describe "fs_running lambda" do
      it "passes #create_change! call to error logger" do
        expect(freshservice).to receive(:create_change!).with("www", "2.0", `hostname`.strip)
        expect(subject).to receive(:err_logger).and_yield
        subject.freshservice_callbacks[:fs_running].call "www", "2.0"
      end
    end

    describe "fs_finished lambda" do
      it "passes #add_note_with_log! call to error logger" do
        upgrade_log = double "upgrade log"
        expect(freshservice).to receive(:change_id).and_return 1
        expect(freshservice).to receive(:add_note_with_log!).with(upgrade_log)
        expect(subject).to receive(:err_logger).and_yield
        subject.freshservice_callbacks[:fs_finished].call upgrade_log
      end
    end

    describe "fs_error" do
      it "passes #add_note! call to error logger" do
        expect(freshservice).to receive(:change_id).and_return 1
        expect(freshservice).to receive(:add_note!).with("ERROR!")
        expect(subject).to receive(:err_logger).and_yield
        subject.freshservice_callbacks[:fs_error].call "ERROR!"
      end
    end

    describe "error_logger" do
      it "rescues, logs errors" do
        e = StandardError.new "ERROR!!"
        expect(e).to receive(:log_me)
        expect {subject.err_logger { raise e }}.not_to raise_exception
      end
    end
  end
end
