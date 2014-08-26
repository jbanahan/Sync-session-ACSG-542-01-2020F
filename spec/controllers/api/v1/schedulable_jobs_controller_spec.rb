require 'spec_helper'

describe Api::V1::SchedulableJobsController do

  describe "run_jobs" do
    context "admin user" do
      before :each do
        @u = Factory(:admin_user)
        allow_api_access @u
      end

      it "runs all schdulable jobs and search schedules that should be run" do
        sj = SchedulableJob.create! run_monday: true, run_tuesday: true, run_wednesday: true, run_thursday: true, run_friday: true, run_saturday: true, run_sunday: true, run_interval: "1m", time_zone_name: "Eastern Time (US & Canada)", last_start_time: 1.day.ago
        SchedulableJob.any_instance.should_receive(:delay).and_return sj
        sj.should_receive(:run_if_needed)

        ss = Factory(:search_schedule, run_monday: true, run_tuesday: true, run_wednesday: true, run_thursday: true, run_friday: true, run_saturday: true, run_sunday: true, run_hour: 0, last_start_time: 1.year.ago, )
        SearchSchedule.any_instance.should_receive(:delay).and_return ss
        ss.should_receive(:run_if_needed)

        post "run_jobs", {}
        expect(response.body).to eq ({"OK" => "", "jobs_run" => 2}.to_json)
      end

      it "does not run jobs that are not ready to run" do
        sj = SchedulableJob.create! 
        ss = Factory(:search_schedule)

        post "run_jobs", {}
        expect(response.body).to eq ({"OK" => "", "jobs_run" => 0}.to_json)
      end
    end

    context "non-admin user" do
      it "does not allow non-admin users to connect" do
        u = Factory(:user)
        allow_api_access u

        post "run_jobs", {}
        expect(response.status).to eq 401
      end
    end
  end
end