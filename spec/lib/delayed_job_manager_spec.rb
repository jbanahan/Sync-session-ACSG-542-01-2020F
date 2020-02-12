describe DelayedJobManager do

  class MockMemcache
    attr_accessor :cache
    def initialize
      @cache = {}
    end

    def get key
      @cache[key]
    end

    def set key, value
      @cache[key] = value
    end
  end

  let! (:master_setup) { stub_master_setup }

  let (:cache) {
    MockMemcache.new
  }

  subject { described_class }

  before :each do
    allow(subject).to receive(:memcache).and_return cache
  end

  describe 'monitor_backlog' do

    it "monitors queue backlog and emails if messages are backed up" do
      "word".delay({run_at: 16.minutes.ago, queue: "default"}).size
      "word".delay({run_at: 16.minutes.ago, queue: "default"}).size

      expect(Lock).to receive(:acquire).with("Monitor Queue Backlog", yield_in_transaction: false).and_yield
      expect(OpenChain::CloudWatch).to receive(:send_delayed_job_queue_depth).with(2)
      expect(subject.monitor_backlog max_messages: 1).to eq true

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      expect(mail.subject).to include "#{master_setup.system_code} - Delayed Job Queue Too Big: 2 Items"
      expect(cache.get("DelayedJobManager:next_backlog_warning")).not_to be_nil
      expect(cache.get("DelayedJobManager:next_backlog_warning")).to be_within(15.minutes).of(Time.zone.now)
    end

    it "does not report items younger than threshold" do
      "word".delay({run_at: 15.minutes.ago, queue: "default"}).size
      "word".delay({run_at: 15.minutes.ago, queue: "default"}).size
      expect(OpenChain::CloudWatch).to receive(:send_delayed_job_queue_depth).with(0)
      expect(subject.monitor_backlog max_messages: 1, max_age_minutes: 30).to eq false
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "skips checking for backlog if recently checked" do
      cache.set("DelayedJobManager:next_backlog_warning", Time.zone.now + 15.minutes)
      "word".delay({run_at: 16.minutes.ago, queue: "default"}).size
      "word".delay({run_at: 16.minutes.ago, queue: "default"}).size
      # Even if we don't email, we still should be putting metrics into CloudWatch
      expect(OpenChain::CloudWatch).to receive(:send_delayed_job_queue_depth).with(2)
      expect(subject.monitor_backlog max_messages: 1).to eq false
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "only checks the default queue" do
      "word".delay({run_at: 16.minutes.ago, queue: "notdefault"}).size
      "word".delay({run_at: 16.minutes.ago, queue: "notdefault"}).size
      expect(OpenChain::CloudWatch).to receive(:send_delayed_job_queue_depth).with(0)
      expect(subject.monitor_backlog max_messages: 1).to eq false
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "retries 3 times to acquire lock" do
      e = Timeout::Error.new "Error"
      expect(Lock).to receive(:acquire).with("Monitor Queue Backlog", yield_in_transaction: false).exactly(3).times.and_raise e
      expect { subject.monitor_backlog max_messages: 1 }.to raise_error e
    end
  end

  describe "report_delayed_job_error" do
    let (:errored_job) { 
      j = Delayed::Job.new
      j.last_error = "Error!"
      j.save!
      j
    }

    it "reports delayed jobs with errors" do
      errored_job
      expect(Lock).to receive(:acquire).with("Report Delayed Job Error", yield_in_transaction: false).and_yield
      expect(OpenChain::CloudWatch).to receive(:send_delayed_job_error_count).with(1)
      expect(DelayedJobManager.report_delayed_job_error).to eq true
      email = ActionMailer::Base.deliveries.last
      expect(email).not_to be_nil
      expect(email.subject).to include "#{master_setup.system_code} - 1 delayed job(s) have errors."
      expect(email.body.raw_source).to include "Job Error: Error!"
      expect(cache.get("DelayedJobManager:next_report_delayed_job_error")).not_to be_nil
      expect(cache.get("DelayedJobManager:next_report_delayed_job_error")).to be_within(16.minutes).of(Time.zone.now)
    end

    it "does not send an error if no jobs are found" do
      expect(OpenChain::CloudWatch).to receive(:send_delayed_job_error_count).with(0)
      expect(DelayedJobManager.report_delayed_job_error ).to eq false
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "does not send an error if errors were reported less than reporting age time ago" do
      cache.set("DelayedJobManager:next_report_delayed_job_error", Time.zone.now + 15.minutes)
      errored_job
      expect(OpenChain::CloudWatch).not_to receive(:send_delayed_job_error_count)
      expect(DelayedJobManager.report_delayed_job_error).to eq false
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "trims excessively long error messages" do
      m = "Really long error message..repeat ad nauseum"
      begin
        m += m
      end while m.length <= 500
      errored_job.last_error = m
      errored_job.save!
      expect(OpenChain::CloudWatch).to receive(:send_delayed_job_error_count).with(1)
      expect(DelayedJobManager.report_delayed_job_error).to eq true
      email = ActionMailer::Base.deliveries.last
      expect(email.body.raw_source).to include "Job Error: " + m.slice(0, 500)
    end

    it "respects max error count" do 
      errored_job

      job_2 = Delayed::Job.new
      job_2.record_timestamps = false
      job_2.last_error = "Job 2 Error"
      job_2.created_at = Time.zone.parse("2018-01-01 12:00")
      job_2.updated_at = Time.zone.parse("2018-01-01 12:00")
      job_2.save!
      expect(OpenChain::CloudWatch).to receive(:send_delayed_job_error_count).with(2)
      expect(DelayedJobManager.report_delayed_job_error max_error_count: 1).to eq true
      email = ActionMailer::Base.deliveries.last
      expect(email.body.raw_source).to include "Job Error: Error!"
      expect(email.body.raw_source).not_to include "Job Error: Job 2 Error"
    end

    it "retries 3 times to acquire lock" do
      e = Timeout::Error.new "Error"
      expect(Lock).to receive(:acquire).with("Report Delayed Job Error", yield_in_transaction: false).exactly(3).times.and_raise e
      expect { subject.report_delayed_job_error }.to raise_error e
    end
  end

end
