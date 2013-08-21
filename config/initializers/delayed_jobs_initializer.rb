require 'delayed_job'
require 'open_chain/upgrade'

class ChainDelayedJobPlugin < Delayed::Plugin

  def self.is_upgrade_delayed_job? job
    # Scan the jobs handler (yaml serialization) to see if it contains a reference to the 
    # method call which runs the upgrade process on the delayed job machine.

    # The reason we're doing this by method reference is so that we throw an error if the upgrade method is
    # moved or renamed, rather than just failing silently.
    begin
      job.handler.include? "method_name: :#{OpenChain::Upgrade.method(:upgrade_delayed_job_if_needed).name}"
    rescue NameError
      $!.log_me
    end
  end

  def self.upgrade_started? 
    # The upgrade in progress check relies on checking the existence of an upgrade_running file, however, this
    # file is cleaned up after the upgrade is complete, so we then we're using the check for the config version
    # number vs. code version as the fallback to see if an upgrade was run.  This is done as a fallback since
    # the in_progress? will detect an upgrade being started before the code version check will, and the code
    # version check is here because the upgrade in_progress check will return false after the upgrade is completed.
    OpenChain::Upgrade.in_progress? || (MasterSetup.current_code_version != MasterSetup.current_config_version)
  end

  callbacks do |lifecycle|
    # FYI..this call is currently made from delayed_job's worker.rb via the run_callbacks call.  Args passed to that method
    # (after the callback's identifier symbol) are what are passed into this block. args splat is here just in 
    # case any future args are added so that they'll get passed down the callback chain
    lifecycle.around(:perform) do |worker, job, *args, &block| 

      # This is used in conjunction with the dj_monitor.sh script to ensure only job queues running the most up 
      # to date version of the code stay running.  If we kill off outdated queues, the monitor script will then
      # restart the job queues.
      if MasterSetup.need_upgrade? && !is_upgrade_delayed_job?(job)
        raise "Should have run upgrade: #{is_upgrade_delayed_job?(job)}" if job.id == 17
        # We can actually save off this job just by rescheduling it, that way after the upgrade is complete it will
        # run with any updated code.  The job attempts reset is to prevent the reschedule from running too many times and
        # having it kill the job.
        job.attempts -= 1
        job.last_error = "This job queue was running the outdated code version '#{MasterSetup.current_code_version}'.  Requeing job to run in updated queue."
        # By including the job's run_at time, we avoid the delayed job manager pushing the next run_at time forward.
        # This means that once the delayed job queue is back running the original job order should be preserved.
        worker.reschedule(job, job.run_at)

        # If we're in the process of upgrading, we shouldn't run any more delayed jobs with this worker.
        # We can actually tell the worker to stop, which will shut down this current worker process after it 
        # handles any cleanup on this job.

        # We only want to stop the worker if we know an update has already been started, othewise, it's possible
        # if there's enough jobs in the queue ahead of the delayed job upgrade job that we'll kill off all the workers
        # prior to the actual upgrade job being run.
        worker.stop if ChainDelayedJobPlugin.upgrade_started?

        # We're going to purposefully NOT forward to anything in the callback chain since we're, in effect, cancelling
        # this job's run.
        false
      else
        # Call through to any other plugins that may be attached to this callback chain, the last 
        # callback in the chain is always the execution of the job
        block.call(worker, job, *args)
      end
    end

    # The loop callback occurs in the delayed_job worker before it attempts to even start checking for jobs to run.
    # We can listen on that callback and tell it to not bother doing the job lookups and kill ourself if we're already
    # in the process of upgrading.
    lifecycle.around(:loop) do |worker, *args, &block|
      # Check if an upgrade was initiated, and then determine if an update was actually started already 
      # (and thus we should commit sepuku) by seeing if the config file's code version on disk 
      # doesn't match our process' current code version - which would mean an update to the new source code 
      # version occurred (ergo an update is already running in a new version).
      if MasterSetup.need_upgrade? && ChainDelayedJobPlugin.upgrade_started? 
        worker.stop
        nil
      else
        block.call(worker, *args)
      end
    end
  end
end

Delayed::Worker.plugins << ChainDelayedJobPlugin