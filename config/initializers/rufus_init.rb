#CODE COPIED FROM: https://github.com/jmettraux/rufus-scheduler/issues/10/
require 'rufus/scheduler'
require 'open_chain/delayed_job_manager'
require 'open_chain/upgrade'

def execute_scheduler
  # Create your scheduler here
  scheduler = Rufus::Scheduler.start_new  
  
  # Set an exception handler to just call the exception's log_me method so we can
  # track down issues
  def scheduler.handle_exception(job, exception) 
    exception.log_me
  end

  #check for upgrades for the web servers (allow overlapping is supposed to only allow a single instance of this job to run on this scheduler)
  upgrade_job_options = {:tags => "Upgrade", :allow_overlapping => false}
  scheduler.every '30s', upgrade_job_options do
    if Rails.env.production?
      upgrade_running = lambda do
        # Unschedule all job except the upgrade ones - this doesn't stop jobs in progress, just effectively
        # stops the scheduler from running re-running them after this moment
        jobs = scheduler.all_jobs.values
        jobs.each_entry {|j| j.unschedule unless j.try(:tags).try(:include?, upgrade_job_options[:tags])}

        # Wait till all running jobs aside from Upgrade jobs are completed.
        upgrade_job_ids = jobs.collect {|j| j.try(:tags).try(:include?, upgrade_job_options[:tags]) ? j.job_id : nil}.compact
        # Sleep for at most 10 seconds...there's really no job below that should run for more than a second or two
        # since they're all pretty much just kicking off delayed jobs anyway
        sleep_iterations = 0
        while sleep_iterations < 20 && jobs.select {|j| j.running && !upgrade_job_ids.include?(j.job_id)}.length > 0
          sleep 0.5
          sleep_iterations += 1
        end
      end

      # Don't kick off another upgrade if we've already upgraded
      unless OpenChain::Upgrade.upgraded?
        OpenChain::Upgrade.upgrade_if_needed running: upgrade_running
      end
    end
  end

  # Check for upgrade to delayed job server
  scheduler.every '30s', upgrade_job_options do
    if Rails.env.production?
      # Make sure the upgrades are set to be the "highest" priority so they jump to the 
      # front of the queue.  The lower the value, the higher priority the job gets in delayed_job
      # Only queue an upgrade if one's not already queued
      if Delayed::Job.where("handler like '%upgrade_delayed_job_if_needed%'").size == 0
        OpenChain::Upgrade.delay(:priority=>-100).upgrade_delayed_job_if_needed
      end
    end
  end

  #monitor delayed job backlog and watch for delayed job errors
  scheduler.every '5m' do
    DelayedJobManager.monitor_backlog
    DelayedJobManager.report_delayed_job_error
  end

end

if defined?(PhusionPassenger)
  # Passenger is starting a new process
  PhusionPassenger.on_event(:starting_worker_process) do |forked| 
    # Run the rufus scheduler ONLY in the foked web processes
    if forked
      # Execute the rufus scheduler
      execute_scheduler
    end
  end

  # Passenger is shutting down a process.   
  PhusionPassenger.on_event(:stopping_worker_process) do
    # Nothing needs to be done here, but I want to recall that this callback exists
  end
else
  # Allow an easy way to have the scheduler run locally on a dev machine
  if Rails.env.development? && MasterSetup.get.custom_feature?("Run Scheduler")
    execute_scheduler
  end
end

