describe Api::V1::SchedulableJobsController do
  describe "run_jobs" do
    context "admin user" do
      let(:user) { create(:admin_user) }

      before do
        allow_api_access user
      end

      it "runs all schdulable jobs and search schedules that should be run" do
        sj = SchedulableJob.create! run_monday: true, run_tuesday: true, run_wednesday: true, run_thursday: true,
                                    run_friday: true, run_saturday: true, run_sunday: true, run_interval: "1m",
                                    time_zone_name: "Eastern Time (US & Canada)", last_start_time: 1.day.ago
        expect_any_instance_of(SchedulableJob).to receive(:delay).and_return sj
        expect(sj).to receive(:run_if_needed)

        ss = create(:search_schedule, run_monday: true, run_tuesday: true, run_wednesday: true, run_thursday: true,
                                       run_friday: true, run_saturday: true, run_sunday: true, run_hour: 0,
                                       last_start_time: 1.year.ago)
        expect_any_instance_of(SearchSchedule).to receive(:delay).with(priority: -1).and_return ss
        expect(ss).to receive(:run_if_needed)

        post "run_jobs", {}
        expect(response.body).to eq ({"OK" => "", "jobs_run" => 2}.to_json)
      end

      it "queues schedulable jobs using their given priority" do
        sj = SchedulableJob.create! run_monday: true, run_tuesday: true, run_wednesday: true, run_thursday: true,
                                    run_friday: true, run_saturday: true, run_sunday: true, run_interval: "1m",
                                    time_zone_name: "Eastern Time (US & Canada)", last_start_time: 1.day.ago,
                                    queue_priority: -100
        expect_any_instance_of(SchedulableJob).to receive(:delay).with(priority: -100).and_return sj
        expect(sj).to receive(:run_if_needed)

        post "run_jobs", {}
        expect(response.body).to eq ({"OK" => "", "jobs_run" => 1}.to_json)
      end

      it "does not run jobs that are not ready to run" do
        SchedulableJob.create!
        create(:search_schedule)

        post "run_jobs", {}
        expect(response.body).to eq ({"OK" => "", "jobs_run" => 0}.to_json)
      end
    end

    context "non-admin user" do
      it "does not allow non-admin users to connect" do
        u = create(:user)
        allow_api_access u

        post "run_jobs", {}
        expect(response.status).to eq 403
      end
    end
  end
end