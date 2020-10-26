module Api; module V1; class SchedulableJobsController < ApiController

  before_action :require_admin

  def run_jobs
    # Run all Search Schedules and Schedulable Jobs
    # This action is expected to be hit every minute or so (curl request running from cron job), it is the
    # primary means of executing scheduled processes.
    jobs_run = 0

    # Work progressively through the search schedule list instead of all at once
    SearchSchedule.find_in_batches(batch_size: 100) do |schedules|
      jobs_run += run_schedules schedules, true
    end

    SchedulableJob.find_in_batches(batch_size: 100) do |schedules|
      jobs_run += run_schedules schedules, false
    end

    render json: {"OK" => "", "jobs_run" => jobs_run}
  end

  private

    def run_schedules schedules, is_search_schedule
      jobs_run = 0
      schedules.each do |ss|
        if ss.needs_to_run?
          # Give search schedules a slightly higher priority than other things in the background queue
          if is_search_schedule
            ss = ss.delay(priority: -1)
          elsif ss.respond_to?(:queue_priority) && !ss.queue_priority.nil?
            ss = ss.delay(priority: ss.queue_priority)
          else
            ss = ss.delay
          end

          ss.run_if_needed
          jobs_run += 1
        end
      end
      jobs_run
    end

end; end; end