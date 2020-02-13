require 'delayed_job'
require 'open_chain/upgrade'
require 'get_process_mem'

module OpenChain; class ChainDelayedJobPlugin < Delayed::Plugin

  cattr_accessor :next_memory_check

  def self.is_upgrade_delayed_job? job
    # Scan the jobs handler (yaml serialization) to see if it contains a reference to the 
    # method call which runs the upgrade process on the delayed job machine.

    # The reason we're doing this by method reference is so that we throw an error if the upgrade method is
    # moved or renamed, rather than just failing silently.
    begin
      return job.handler.include? "method_name: :#{OpenChain::Upgrade.method(:upgrade_delayed_job_if_needed).name}"
    rescue NameError => e
      # If we get a name error here, it means the OpenChain::Upgrade class (or the upgrade_delayed_job_if_needed method)
      # does't exist...which is bad, so notify immediately.
      e.log_me
      return false
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
    path = MasterSetup.instance_directory.join("log", "delayed_job.log")
    stdout, stderr, status = Open3.capture3({}, *["lsof", "-t", path.to_s])
    # One thing to watch out for, lsof returns a status code of 1 (failure) if no processes have an open handle
    # to the log file.  Not entirely expected, but if that's the case, then there's no reason to parse the output
    if status.success?
      stdout.to_s.each_line.count
    else
      0
    end
  end

  def self.do_upgrade?
    MasterSetup.production_env? && MasterSetup.upgrades_allowed? && MasterSetup.need_upgrade?
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

  # Determines whether we should continue running the current worker or not.
  #
  # At the moment, it only checks if the current worker is utilizing too much memory.
  #
  # I can see other heuristics also being used in the future, which is why this method exists as an 
  # external touch point.
  #
  # Returns true if continue or false if not
  def self.stop_worker_post_job_completion?
    memory_limit_exceeded?(Time.zone.now, MasterSetup.config_value('delayed_job_max_memory', default: 1_250))
  end

  # This method will determine if the current process' memory exceeds
  # the given limit (in MB).  This method will only actually run a memory
  # check if the given current time is AFTER the expected next check time
  # (which can be configured with a vfitrack_settings.yml key/value of 'delayed_job_memory_check_interval')
  #
  # If a memory check is actually performed, then the next check time is incremented by the internal
  # number of minutes.
  #
  # returns true if memory check executed and memory exeeded given max, otherwise false
  def self.memory_limit_exceeded? current_time, max_memory_allowed_mb
    time_increment = MasterSetup.config_value('delayed_job_memory_check_interval', default: 5).to_i.minutes
    exceeded_limit = false
    recalc_next_memory_check = false
    next_check = self.next_memory_check
    if next_check.present?
      if current_time > next_check

        exceeded_limit = memory_usage_in_mb > max_memory_allowed_mb
        recalc_next_memory_check = true
      end
    else
      recalc_next_memory_check = true
    end

    if recalc_next_memory_check
      self.next_memory_check = current_time + time_increment
    end

    exceeded_limit
  end

  def self.worker_identifier
    "#{MasterSetup.hostname}:#{Process.pid}"
  end

  def self.memory_usage_in_mb
    m = GetProcessMem.new
    megabytes = m.mb
    Rails.logger.info { "DelayedJob #{worker_identifier} is utilizing #{megabytes} MB of memory." }
    megabytes
  end
  private_class_method :memory_usage_in_mb

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
          if OpenChain::ChainDelayedJobPlugin.number_of_running_queues > 1 && OpenChain::ChainDelayedJobPlugin.upgrade_started?
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
          OpenChain::ChainDelayedJobPlugin.job_wrapper(job) do |job|
            result = block.call(worker, job, *args)

            # When we stop the worker here, we're relying on the job queue monitoring script to restart it.
            # The script runs as a service, so it's always running and will restart the job worker within 
            # a minute or so once it notices this system's queue is down one queue.
            if upgrade_job
              worker.stop if OpenChain::Upgrade.upgraded?
            else
              if OpenChain::ChainDelayedJobPlugin.stop_worker_post_job_completion?
                Rails.logger.info("Stopping DelayedJob worker #{worker.name} due to post job completion instruction.")
                worker.stop
              end
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

end; end