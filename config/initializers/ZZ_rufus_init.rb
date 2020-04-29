# CODE COPIED FROM: https://github.com/jmettraux/rufus-scheduler/issues/10/
require 'rufus-scheduler'
require 'open_chain/delayed_job_manager'
require 'open_chain/upgrade'

module OpenChain; class WebScheduler

  def self.execute_scheduler
    # check for upgrades for the web servers (allow overlapping is supposed to only allow a single instance of this job to run on this scheduler)
    upgrade_job_options = {tags: "Upgrade", allow_overlapping: false}
    scheduler.every '30s', upgrade_job_options do
      if MasterSetup.upgrades_allowed?
        upgrade_running = lambda do
          # Unschedule all job except the upgrade ones - this doesn't stop jobs in progress, just effectively
          # stops the scheduler from running re-running them after this moment in time

          # Leave the upgrade jobs running, since if there's an error, the upgrade will automatically re-run once the upgrade_running
          # / error file is cleared
          scheduler.jobs(tag: "Standard").each do |job|
            scheduler.unschedule(job)
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
      if MasterSetup.upgrades_allowed?
        # Make sure the upgrades are set to be the "highest" priority so they jump to the
        # front of the queue.  The lower the value, the higher priority the job gets in delayed_job
        # Only queue an upgrade if one's not already queued

        # Queue and priority are added to the query here so the primary lookup uses the main table index - this can help cut down table scans if the
        # queue gets really big.
        if Delayed::Job.where(queue: Delayed::Worker.default_queue_name, priority: -100).where("handler like '%upgrade_delayed_job_if_needed%'").limit(1).pluck(:id).blank?
          OpenChain::Upgrade.delay(:priority=>-100).upgrade_delayed_job_if_needed
        end
      end
    end

    # monitor delayed job backlog and watch for delayed job errors
    standard_job_options = {tags: "Standard"}
    scheduler.every '5m', standard_job_options do
      DelayedJobManager.monitor_backlog
      DelayedJobManager.report_delayed_job_error
    end
  end

  def self.scheduler
    @scheduler ||= begin
      s = Rufus::Scheduler.singleton
      # Set an exception handler to just call the exception's log_me method so we can
      # track down issues
      def s.on_error(job, exception)
        exception.log_me if exception.respond_to?(:log_me)
      end
      s
    end

    @scheduler
  end
end; end

if defined?(PhusionPassenger)
  # Passenger is starting a new process, if forked is true
  # it means that smart spawning mode is being used...which means socket connections, etc
  # may need to be revived.  Not an issue here.
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    OpenChain::WebScheduler.execute_scheduler
  end
else
  # Allow an easy way to have the scheduler run locally on a dev machine
  # MasterSetup get might be nil on a dev system that has not been init'ed yet
  if Rails.env.development? && MasterSetup.master_setup_initialized? && MasterSetup.get&.custom_feature?("Run Scheduler")
    OpenChain::WebScheduler.execute_scheduler
  end
end

