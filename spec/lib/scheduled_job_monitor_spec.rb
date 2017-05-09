describe OpenChain::ScheduledJobMonitor do

  subject {described_class}

  describe "run_schedulable" do
    let! (:running_job) { SchedulableJob.create! run_class: "Job::Running", no_concurrent_jobs: true, running: true, last_start_time: (Time.zone.now - 10.hours)}
    let! (:waiting_job) { SchedulableJob.create! run_class: "Job::Waiting", no_concurrent_jobs: true, running: false, last_start_time: (Time.zone.now - 10.hours)}
    let! (:stopped_job) { SchedulableJob.create! run_class: "Job::Stopped", no_concurrent_jobs: true, running: false, last_start_time: (Time.zone.now - 10.hours)}
    let! (:concurrent_job) { SchedulableJob.create! run_class: "Job::Concurrent", no_concurrent_jobs: false, running: true, last_start_time: (Time.zone.now - 10.hours)}

    it "reports long running job" do
      subject.run_schedulable

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first

      expect(mail.to).to eq [OpenMailer::BUG_EMAIL]
      expect(mail.subject).to eq "[VFI Track] Long Running Jobs"
      expect(mail.body).to include "Job::Running"
      expect(mail.body).not_to include "Job::Waiting"
      expect(mail.body).not_to include "Job::Stopped"
      expect(mail.body).not_to include "Job::Concurrent"
    end

    it "emails specified account" do
      subject.run_schedulable({"email" => "me@there.com"})
      expect(ActionMailer::Base.deliveries.first.to).to eq ["me@there.com"]
    end
  end
end