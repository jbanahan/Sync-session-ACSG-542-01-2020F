require 'open_chain/cloud_watch'

class DelayedJobManager

  # generate errors if delayed job backlog contains too many messages older than 10 minutes
  def self.monitor_backlog max_messages: 25, reporting_delay_minutes: 15, max_age_minutes: 15
    # By doing this in an x-process lock, it means we'll make sure we only get a single email every 30 minutes (rather than 
    # potentially 3 messages each checkup - .ie 1 message per each web server)
    Lock.acquire("Monitor Queue Backlog", yield_in_transaction: false) do
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

    # If we keep getting lock delays, then we might need to add an index on the last_error (can be a shortened index since error is a text column)
    Lock.acquire("Report Delayed Job Error", yield_in_transaction: false) do
      # Use Memcache as the "database" for the last time the email was sent
      next_warning_time = memcache.get "DelayedJobManager:next_report_delayed_job_error"
      # If we're not ready to send out a notification...then there's not really any point in continuing
      return false if next_warning_time && Time.zone.now < next_warning_time

      errored_jobs = Delayed::Job.where("last_error IS NOT NULL").order("created_at DESC").limit(1000).select(:last_error).all
      real_error_count = errored_jobs.length
    
      error_messages = []
      max_message_length = 500

      errored_jobs.each_with_index do |job, i|
        break if i >= max_error_count
        m = job.last_error.length < max_message_length ? job.last_error : job.last_error[0, max_message_length]
        error_messages << "Job Error: " + m
      end
      memcache.set "DelayedJobManager:next_report_delayed_job_error", min_reporting_age_minutes.minutes.from_now
    end

    OpenChain::CloudWatch.send_delayed_job_error_count real_error_count

    if real_error_count > 0
      OpenMailer.send_generic_exception(StandardError.new("#{MasterSetup.get.system_code} - #{real_error_count} delayed job(s) have errors."), error_messages).deliver_now
      return true
    else
      return false
    end
  end

  # This is mostly just a proxy for use w/ test casing...
  def self.memcache
    CACHE
  end
  private_class_method :memcache

end
