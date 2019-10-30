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
    # file is cleaned up after the upgrade is complete, so then we're using the check for the repository release version
    # number vs. code version as the fallback to see if an upgrade was run.  This is done as a fallback since
    # the in_progress? will detect an upgrade being started before the code version check will, and the code
    # version check is here because the upgrade in_progress check will return false after the upgrade is completed.
    OpenChain::Upgrade.in_progress? || (MasterSetup.current_code_version != MasterSetup.current_repository_version)
  end

  def self.number_of_running_queues
    # This command will give us the a \n delimited list of the pids with file handles open on the delayed job log
    # Every different worker opens a file handler here as defined in the delayed job command.rb file which is
    # run from the script/delayed_job file we use.
    `lsof -t #{File.join(Rails.root, 'log', 'delayed_job.log')}`.chomp.split("\n").size
  end

  def self.do_upgrade?
    Rails.env.production? && MasterSetup.upgrades_allowed? && MasterSetup.need_upgrade?
  end

  def self.job_wrapper job
    Thread.current.thread_variable_set("delayed_job", true)
    Thread.current.thread_variable_set("delayed_job_attempts", job.attempts)
    Thread.current.thread_variable_set("delayed_job_queue", job.queue)
    # Before each job we're going to check if model fields need to be updated, if they do, then we'll update
    # them..if not, then we'll run the job and lock them down so no reloads occur during the job run.
    ModelField.reload_if_stale
    ModelField.disable_stale_checks = true
    # This effectively reloads the master setup from memcache before each delayed job and then locks it in place for 
    # the duration of the job.
    MasterSetup.current = MasterSetup.get(false)
    begin
      yield job
    ensure
      Thread.current.thread_variable_set("delayed_job", nil)
      Thread.current.thread_variable_set("delayed_job_attempts", nil)
      Thread.current.thread_variable_set("delayed_job_queue", nil)
      ModelField.disable_stale_checks = false
    end
  end

  callbacks do |lifecycle|
    # FYI..this call is currently made from delayed_job's worker.rb via the run_callbacks call.  Args passed to that method
    # (after the callback's identifier symbol) are what are passed into this block. args splat is here just in 
    # case any future args are added so that they'll get passed down the callback chain
    lifecycle.around(:perform) do |worker, job, *args, &block| 

      # This is used in conjunction with the dj_monitor.sh script to ensure only job queues running the most up 
      # to date version of the code stay running.  If we kill off outdated queues, the monitor script will then
      # restart the job queues.
      upgrade_job = is_upgrade_delayed_job?(job)
      if do_upgrade? && !upgrade_job
        
        # We can actually save off this job just by rescheduling it, that way after the upgrade is complete it will
        # run with any updated code.  The job attempts reset is to prevent the reschedule from running too many times and
        # having it kill the job.
        job.attempts -= 1
        # By including the job's run_at time, we avoid the delayed job manager pushing the next run_at time forward.
        # This means that once the delayed job queue is back running the original job order should be preserved.
        worker.reschedule(job, job.run_at)

        # If we're in the process of upgrading, we shouldn't run any more delayed jobs with this worker.
        # We can actually tell the worker to stop, which will shut down this current worker process after it 
        # handles any cleanup on this job.

        # We only want to stop the worker if we know an update has already been started, otherwise, it's possible
        # if there's enough jobs in the queue ahead of the delayed job upgrade job that we'll kill off all the workers
        # prior to the actual upgrade job being run.
        Lock.acquire(Lock::UPGRADE_LOCK, yield_in_transaction: false) do
          # Don't stop if we're the very last queue
          if ChainDelayedJobPlugin.number_of_running_queues > 1 && ChainDelayedJobPlugin.upgrade_started?
            worker.stop
          end
        end 

        # We're going to purposefully NOT forward to anything in the callback chain since we're, in effect, cancelling
        # this job's run.
        false
      else
        # Call through to any other plugins that may be attached to this callback chain, the last 
        # callback in the chain is always the execution of the job (which will return true if the job ran without error
        # and false if it errored).
        result = false
        # We really shouldn't have a case where we're getting an upgrade job in this process after we've already
        # run one, but since it's so easy to guard against we'll handle it just in case.
        unless OpenChain::Upgrade.upgraded?
          ChainDelayedJobPlugin.job_wrapper(job) do |job|
            result = block.call(worker, job, *args)

            if upgrade_job
              worker.stop if OpenChain::Upgrade.upgraded?
            end
          end
        end
        result
      end
    end

    # The loop callback occurs in the delayed_job worker before it attempts to even start checking for jobs to run.
    # We can listen on that callback and tell it to stop our current worker process if another worker process is
    # in the process of upgrading.

    # This callback is pretty much entirely here to make sure all the other job queues are shut down as the update is concurrently running.
    # If this isn't done then it's very possible if no other jobs are queued during the upgrade one of the waiting queues will start 
    # another upgrade process after the other is completed (since the above callback to stop the queues only runs if a job is picked up).
    # It relies on the sleep time between job checks for the worker (Delayed::Worker.sleep_dealy) to be set in such a manner that there's 
    # no way a queue can be sleeping during the entirety of the upgrade process. By default, the sleep time is 1 second.
    lifecycle.before(:loop) do |worker, *args|

      # We need to make sure that we allow for cases where the upgrade ran and errored out - which leaves the running flag file in place.
      # We want to keep at least a single queue alive when this happens so that when we fix the issue and clear the 
      # upgrade_running.txt file the upgrade will automatically pick up and go without us having to manually spin up a delayed job queue.
      if OpenChain::Upgrade.in_progress? && !OpenChain::Upgrade.errored?
        worker.stop
      end
    end
  end
end

# Add our plugin to the worker's plugin list.
Delayed::Worker.plugins << ChainDelayedJobPlugin

# The following sorta monkey patches support for telling delayed jobs to NOT reschedule a failed job if the error class is UnreportedError.
# There doesn't seem to be a way to hook the lifecyle to get at the actual errors raised by a job when the Object.delay.method approach
# is used.  Even the callbacks for the custom jobs approach seem to only allow for reporting the error and not for killing off the job.
module OpenChain; module UnreportedErrorFailedJobHandler

  def handle_failed_job job, error, *args
    if error.is_a?(UnreportedError)
      job.destroy
    else
      super
    end
  end

end; end

module Delayed; class Worker
  # prepend used here because we effectively want to override the 'handle_failed_job' method in the base
  # Woker class with our re-implementation from UnreportedErrorFailedJobHandler
  prepend OpenChain::UnreportedErrorFailedJobHandler
  
end; end;

# Allow the job queue name to come from the vfitrack_settings.yml config file too.
# By setting this value, every single call to .delay() effectively becomes .delay(queue: "anothervalue").
# This can be useful if we want to spin up secondary job processing machines and run scripts/jobs that result in the job 
# queue being utilized.  By having these jobs queue to a different queue name, we can effectively isolate their impact
# on the primary job queue system and run all these jobs via a secondary one, limiting the impact on the primary product queue.
#
# This can be especially useful in cases where we might need to reprocess a lot of objects/snapshots and want to use a second job queue 
# ec2 instance.
#
# Note: For the actual delayed job worker process, the Delayed Job "queues" command line option superceeds this setting.
# So for the actual delayed jobs process that might need to be run to process jobs in an alternate queue
# you need to set the alternate queue value in a `config/dj_queue.txt` file (see scripts/start_dj.sh).
Delayed::Worker.default_queue_name = MasterSetup.config_value(:delayed_job_queue_name, default: 'default')

# The following setting tells the delayed worker process to raise a signal error and exit immediately when a TERM signal 
# is received by the worker process.  What this does is kill the job (regardless of its state) and remove the db lock
# indicators immediately when a TERM signal is received.
#
# The standard job stop process (executed by the daemons gem which delayed_job utilizes under the covers) is to issue
# an INT signal to the process first.  The worker will then attempt to complete any job it is currently running.  If
# the worker process does not exit after several seconds, then the daemon process issues a TERM signal to the process.
# This should result in the job stopping immediately, logging a signal error, cleaning up the locks and then exiting.
# This is a clean exiting process as the job can now be picked up by another worker process.
Delayed::Worker.raise_signal_exceptions = :term
