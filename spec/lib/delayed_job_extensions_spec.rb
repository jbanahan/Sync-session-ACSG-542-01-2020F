describe OpenChain::DelayedJobExtensions do
  subject { Class.new { include OpenChain::DelayedJobExtensions }.new }

  describe "get_class" do

    let(:job) { Delayed::Job.new }

    it "returns line from dj handler field containing the class name" do
      job.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult\n  attributes:\n    id: 126\n"
      expect(subject.get_class job).to eq "object: !ruby/ActiveRecord:ReportResult"
    end

    it "returns nil if line doesn't have correct format" do
      job.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: ReportResult\n  attributes:\n    id: 126\n"
      expect(subject.get_class job).to be_nil
    end
  end

  describe "group_jobs" do
    it "returns a hash matching a dj with an array of jobs of the same class (each not locked and having a last_error)" do
      dj_1 = Delayed::Job.create!
      dj_1.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_1.last_error = "Error!"
      dj_2 = Delayed::Job.create!
      dj_2.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:User"
      dj_2.last_error = "Error!"
      dj_3 = Delayed::Job.create!
      dj_3.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_3.last_error = "Error!"
      dj_no_error = Delayed::Job.create!
      dj_no_error.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_locked = Delayed::Job.create!
      dj_locked.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_locked.last_error = "Error!"
      dj_locked.locked_at = DateTime.now
      [dj_1, dj_2, dj_3, dj_no_error, dj_locked].each(&:save!)

      expect(subject.group_jobs).to eq({dj_1.id => [dj_1.id, dj_3.id],
                                          dj_2.id => [dj_2.id],
                                          dj_3.id => [dj_1.id, dj_3.id]
                                          })
    end
  end

  describe "queued_jobs_for_method" do
    it "determines the correct number of running jobs" do
      OpenChain::AllianceImagingClient.delay.run_schedulable
      expect(subject.queued_jobs_for_method(OpenChain::AllianceImagingClient, :run_schedulable)).to eq 1
    end

    it "does not return counts for jobs that are not locked" do
      OpenChain::AllianceImagingClient.delay.run_schedulable
      expect(subject.queued_jobs_for_method(OpenChain::AllianceImagingClient, :run_schedulable, true)).to eq 0
    end

  end

  describe "currently_running_as_delayed_job" do
    it "recognizes when not running in a delayed job" do
      expect(subject.class.currently_running_as_delayed_job?).to eq false
    end

    context "when running as delayed job" do
      before(:each) { Thread.current.thread_variable_set("delayed_job", true)}
      after(:each) { Thread.current.thread_variable_set("delayed_job", nil)}

      it "recognizes when running in a delayed job" do
        expect(subject.class.currently_running_as_delayed_job?).to eq true
      end
    end
  end

  describe "currently_running_delayed_job_attempts" do
    it "returns 0 when not in delayed job" do
      expect(subject.class.currently_running_delayed_job_attempts).to eq 0
    end

    context "when running as delayed job" do
      before(:each) { Thread.current.thread_variable_set("delayed_job_attempts", 5)}
      after(:each) { Thread.current.thread_variable_set("delayed_job_attempts", nil)}

      it "recognizes when running in a delayed job" do
        expect(subject.class.currently_running_delayed_job_attempts).to eq 5
      end
    end
  end

  describe "currently_running_delayed_job_queue" do
    it "returns nil when not in delayed job" do
      expect(subject.class.currently_running_delayed_job_queue).to be_nil
    end

    context "when running as delayed job" do
      before(:each) { Thread.current.thread_variable_set("delayed_job_queue", "queue")}
      after(:each) { Thread.current.thread_variable_set("delayed_job_queue", nil)}

      it "recognizes when running in a delayed job" do
        expect(subject.class.currently_running_delayed_job_queue).to eq "queue"
      end
    end
  end
end