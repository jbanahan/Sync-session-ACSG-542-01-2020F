require 'open_chain/chain_delayed_jobs_plugin'

# Add our plugin to the worker's plugin list.
Delayed::Worker.plugins << OpenChain::ChainDelayedJobPlugin

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
