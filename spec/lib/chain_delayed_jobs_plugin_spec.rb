describe OpenChain::ChainDelayedJobPlugin do

  let (:job) {
    instance_double(Delayed::Job)
  }

  subject { described_class }

  describe "is_upgrade_delayed_job" do
    it "identifies 'OpenChain::Upgrade#upgrade_delayed_job_if_needed' method as upgrade job" do
      # The following should create a handler string that's very similiar (if not identical) to what's is serialized
      # when "OpenChain::Upgrade.delay.upgrade_delayed_job_if_needed" is run
      handler = {payload_object: Delayed::PerformableMethod.new(OpenChain::Upgrade, "upgrade_delayed_job_if_needed", nil)}.to_yaml
      expect(job).to receive(:handler).and_return handler

      expect(subject.is_upgrade_delayed_job? job).to eq true
    end

    it "does not identify other methods as 'OpenChain::Upgrade#upgrade_delayed_job_if_needed'" do
      handler = {payload_object: Delayed::PerformableMethod.new(OpenChain::Upgrade, "upgrade_if_needed", nil)}.to_yaml
      expect(job).to receive(:handler).and_return handler

      expect(subject.is_upgrade_delayed_job? job).to eq false
    end

    it "logs NameError" do
      e = NameError.new
      expect(job).to receive(:handler).and_raise e
      expect(e).to receive(:log_me)
      expect(subject.is_upgrade_delayed_job? job).to eq false
    end
  end

  describe "upgrade_started?" do
    it "returns true if upgrade is in progress" do
      expect(OpenChain::Upgrade).to receive(:in_progress?).and_return true
      expect(subject.upgrade_started?).to eq true
    end

    it "returns true if current code version doesn't equal what's in the repo" do
      expect(OpenChain::Upgrade).to receive(:in_progress?).and_return false
      expect(MasterSetup).to receive(:current_code_version).and_return "1"
      expect(MasterSetup).to receive(:current_repository_version).and_return "2"

      expect(subject.upgrade_started?).to eq true
    end

    it "returns false if upgrade not in progress and code versions are equal" do
      expect(OpenChain::Upgrade).to receive(:in_progress?).and_return false
      expect(MasterSetup).to receive(:current_code_version).and_return "1"
      expect(MasterSetup).to receive(:current_repository_version).and_return "1"

      expect(subject.upgrade_started?).to eq false
    end
  end

  describe "number_of_running_queues" do
    it "uses 'lsof' command to determine number of queues running" do
      status = instance_double(Process::Status)
      expect(MasterSetup).to receive(:instance_directory).and_return Pathname.new("/test")
      expect(status).to receive(:success?).and_return true
      expect(Open3).to receive(:capture3).with({}, "lsof", "-t", "/test/log/delayed_job.log").and_return(["123\n456\n", "", status])

      expect(subject.number_of_running_queues).to eq 2
    end

    it "returns 0 if no queues are running" do
      status = instance_double(Process::Status)
      expect(MasterSetup).to receive(:instance_directory).and_return Pathname.new("/test")
      expect(status).to receive(:success?).and_return true
      expect(Open3).to receive(:capture3).with({}, "lsof", "-t", "/test/log/delayed_job.log").and_return(["", "", status])

      expect(subject.number_of_running_queues).to eq 0
    end

    it "returns 0 if command was unsuccessful" do
      status = instance_double(Process::Status)
      expect(MasterSetup).to receive(:instance_directory).and_return Pathname.new("/test")
      expect(status).to receive(:success?).and_return false
      expect(Open3).to receive(:capture3).with({}, "lsof", "-t", "/test/log/delayed_job.log").and_return(["123\n456\n", "Something failed", status])

      expect(subject.number_of_running_queues).to eq 0
    end
  end

  describe "do_upgrade?" do
    it "returns true if production env, upgrades are allowed, and needs an upgrade" do
      expect(MasterSetup).to receive(:production_env?).and_return true
      expect(MasterSetup).to receive(:upgrades_allowed?).and_return true
      expect(MasterSetup).to receive(:need_upgrade?).and_return true

      expect(subject.do_upgrade?).to eq true
    end

    it "returns false if not production env" do
      expect(MasterSetup).to receive(:production_env?).and_return false
      allow(MasterSetup).to receive(:upgrades_allowed?).and_return true
      allow(MasterSetup).to receive(:need_upgrade?).and_return true

      expect(subject.do_upgrade?).to eq false
    end

    it "returns false if production env, and upgrades are not allowed" do
      expect(MasterSetup).to receive(:production_env?).and_return true
      expect(MasterSetup).to receive(:upgrades_allowed?).and_return false
      allow(MasterSetup).to receive(:need_upgrade?).and_return true

      expect(subject.do_upgrade?).to eq false
    end

    it "returns false if production env, upgrades are allowed, and does not need an upgrade" do
      expect(MasterSetup).to receive(:production_env?).and_return true
      expect(MasterSetup).to receive(:upgrades_allowed?).and_return true
      expect(MasterSetup).to receive(:need_upgrade?).and_return false

      expect(subject.do_upgrade?).to eq false
    end
  end

  describe "memory_limit_exceeded?" do
    let! (:master_setup) {
      allow(MasterSetup).to receive(:config_value).with('delayed_job_memory_check_interval', {default: 5}).and_return 1
    }

    it "returns true if memory limit is higher than given threshold" do
      now = Time.zone.now
      Timecop.freeze(now) do
        expect(subject).to receive(:next_memory_check).and_return (now - 1.minute)
        expect_any_instance_of(GetProcessMem).to receive(:mb).and_return 100
        expect(subject).to receive(:next_memory_check=).with((now + 1.minute))
        expect(subject.memory_limit_exceeded? now, 99).to eq true
      end
    end

    it "returns false if memory limit is lower than given threshold" do
      now = Time.zone.now
      Timecop.freeze(now) do
        expect(subject).to receive(:next_memory_check).and_return (now - 1.minute)
        expect_any_instance_of(GetProcessMem).to receive(:mb).and_return 98
        expect(subject).to receive(:next_memory_check=).with((now + 1.minute))
        expect(subject.memory_limit_exceeded? now, 99).to eq false
      end
    end

    it "returns false if it's not time for next memory check" do
      now = Time.zone.now
      Timecop.freeze(now) do
        expect(subject).to receive(:next_memory_check).and_return (now + 1.minute)
        expect(subject).not_to receive(:next_memory_check=)
        expect(subject.memory_limit_exceeded? now, 99).to eq false
      end
    end

    it "returns false if memory check has not been done, but sets next check time" do
      now = Time.zone.now
      Timecop.freeze(now) do
        expect(subject).to receive(:next_memory_check).and_return nil
        expect(subject).to receive(:next_memory_check=).with(now + 1.minute)
        expect(subject.memory_limit_exceeded? now, 99).to eq false
      end
    end
  end

  describe "job_wrapper" do
    let! (:master_setup) {
      ms = stub_master_setup
      expect(MasterSetup).to receive(:get).with(false).and_return ms
      ms
    }

    let (:job) {
      j = instance_double(Delayed::Job)
      allow(j).to receive(:attempts).and_return 1
      allow(j).to receive(:queue).and_return "test_queue"

      j
    }

    it "sets thread variables and reloads state" do
      expect(ModelField).to receive(:reload_if_stale)

      subject.job_wrapper(job) do |j|
        expect(j).to be job

        # At this point the thread variables should be set
        expect(Thread.current.thread_variable_get("delayed_job")).to eq true
        expect(Thread.current.thread_variable_get("delayed_job_attempts")).to eq 1
        expect(Thread.current.thread_variable_get("delayed_job_queue")).to eq "test_queue"
        expect(MasterSetup.current).to be master_setup
        expect(ModelField.disable_stale_checks).to eq true
      end

      # Ensure the thread variables are unset after the block is finished
      expect(Thread.current.thread_variable_get("delayed_job")).to eq nil
      expect(Thread.current.thread_variable_get("delayed_job_attempts")).to eq nil
      expect(Thread.current.thread_variable_get("delayed_job_queue")).to eq nil
      expect(ModelField.disable_stale_checks).to eq false
    end

    it "unsets thread variables even if job raises an error" do
      expect(ModelField).to receive(:reload_if_stale)

      expect {
        subject.job_wrapper(job) do |j|
          expect(Thread.current.thread_variable_get("delayed_job")).to eq true
          expect(Thread.current.thread_variable_get("delayed_job_attempts")).to eq 1
          expect(Thread.current.thread_variable_get("delayed_job_queue")).to eq "test_queue"

          raise "Error"
        end
      }.to raise_error "Error"

      expect(Thread.current.thread_variable_get("delayed_job")).to eq nil
      expect(Thread.current.thread_variable_get("delayed_job_attempts")).to eq nil
      expect(Thread.current.thread_variable_get("delayed_job_queue")).to eq nil
      expect(ModelField.disable_stale_checks).to eq false
    end
  end

  describe "stop_worker_post_job_completion?" do
    it "checks memory and returns that return value" do
      now = Time.zone.now
      expect(MasterSetup).to receive(:config_value).with('delayed_job_max_memory', default: 1_250).and_return 1
      expect(subject).to receive(:memory_limit_exceeded?).with(now, 1).and_return false
      Timecop.freeze(now) { expect(subject.stop_worker_post_job_completion?).to eq false }
    end
  end
end