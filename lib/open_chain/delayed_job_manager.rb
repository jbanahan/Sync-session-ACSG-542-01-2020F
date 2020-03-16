require 'open_chain/cloud_watch'

class DelayedJobManager

  # generate errors if delayed job backlog contains too many messages older than 10 minutes
  def self.monitor_backlog max_messages: 25, reporting_delay_minutes: 15, max_age_minutes: 15
    # By doing this in an x-process lock, it means we'll make sure we only get a single email every 30 minutes (rather than 
    # potentially 3 messages each checkup - .ie 1 message per each web server)

    # A timeout error is swallowed (and the timeout wait is low) because if we have to wait on this lock, it means there's another
    # process already doing this check...ergo, we don't care the lock couldn't be granted because another process is already doing this
    # monitor for us
    Lock.acquire("Monitor Queue Backlog", yield_in_transaction: false, raise_timeout: false, timeout: 5) do
      # In order to effectively monitor the queue size with cloudwatch, we need to 
      c = Delayed::Job.where("run_at < ?", max_age_minutes.minutes.ago)
      if !Delayed::Worker.default_queue_name.blank?
        c = c.where(queue: Delayed::Worker.default_queue_name)
      end

      message_count = c.count

      OpenChain::CloudWatch.send_delayed_job_queue_depth message_count

      # Use Memcache as the "database" for the last time the email was sent
      next_warning_time = memcache.get "DelayedJobManager:next_backlog_warning"
      return false if next_warning_time && Time.zone.now < next_warning_time

      if message_count > max_messages
        OpenMailer.send_generic_exception(StandardError.new("#{MasterSetup.get.system_code} - Delayed Job Queue Too Big: #{message_count} Items")).deliver_now
        memcache.set "DelayedJobManager:next_backlog_warning", reporting_delay_minutes.minutes.from_now
        return true
      end
    end

    return false
  end
  
  # Reports on any errored delayed job (by raising and logging an exception)
  # Returns true if any error was reported, false otherwise
  def self.report_delayed_job_error min_reporting_age_minutes: 15, max_error_count: 50
    real_error_count = nil
    error_messages = []

    # A timeout error is swallowed (and the timeout wait is low) because if we have to wait on this lock, it means there's another
    # process already doing this check...ergo, we don't care the lock couldn't be granted because another process is already doing this
    # monitor for us
    Lock.acquire("Report Delayed Job Error", yield_in_transaction: false, raise_timeout: false, timeout: 5) do
      # Use Memcache as the "database" for the last time the email was sent
      next_warning_time = memcache.get "DelayedJobManager:next_report_delayed_job_error"
      # If we're not ready to send out a notification...then there's not really any point in continuing
      return false if next_warning_time && Time.zone.now < next_warning_time

      # There's a primary key/index on id (not created_at) so using id to determine creation order is the simplest
      # and quickest way (db-wise) to get results order by created at
      job_errors = remove_transient_errors(Delayed::Job.where("last_error IS NOT NULL").order({id: :desc}).limit(1000).pluck(:last_error))
      real_error_count = job_errors.length
    
      error_messages = []
      max_message_length = 500

      job_errors.each_with_index do |last_error, i|
        break if i >= max_error_count
        m = last_error.length < max_message_length ? last_error : last_error[0, max_message_length]
        error_messages << "Job Error: " + m
      end
      memcache.set "DelayedJobManager:next_report_delayed_job_error", min_reporting_age_minutes.minutes.from_now
    end

    # if the error count is nil, it means the Lock acquire failed, so don't bother submitting any metrics.
    if real_error_count
      OpenChain::CloudWatch.send_delayed_job_error_count real_error_count

      if real_error_count > 0
        OpenMailer.send_generic_exception(StandardError.new("#{MasterSetup.get.system_code} - #{real_error_count} delayed job(s) have errors."), error_messages).deliver_now
      end
    end

    return real_error_count.to_i > 0
  end

  def self.remove_transient_errors messages
    # We don't really need to report deadlock errors, they will eventually resolve themselves by being replayed
    messages.select do |m|
      !OpenChain::DatabaseUtils.mysql_deadlock_error_message?(m)
    end
  end

  # This is mostly just a proxy for use w/ test casing...
  def self.memcache
    CACHE
  end
  private_class_method :memcache

end
