require 'open_chain/schedule_support'
class SchedulableJob < ActiveRecord::Base
  include OpenChain::ScheduleSupport
  attr_accessible :day_of_month, :opts, :run_class, :run_friday, :run_hour, :run_monday, :run_saturday, :run_sunday, :run_thursday, 
    :run_tuesday, :run_wednesday, :time_zone_name, :run_minute, :last_start_time, :success_email, :failure_email, :run_interval, :no_concurrent_jobs, :running

  def run log=nil
    begin
      rc = self.run_class.gsub("::",":")
      components = rc.split(":")
      begin
        camel_case_components = components.collect {|c| c.underscore}
        require_path = camel_case_components.join("/")
        require require_path
      rescue LoadError
        #just move on, if we needed the file it'll throw an exception below
        #otherwise this isn't an issue
      end
      k = Kernel
      components.each {|c| k = k.const_get(c)}
      run_opts = opts_hash
      log.info "Running schedule for #{k.to_s} with options #{run_opts}" if log

      raise "No 'run_schedulable' method exists on '#{self.run_class}' class." unless k.respond_to?(:run_schedulable)
      
      method = k.method(:run_schedulable)
      if method.parameters.length == 0
        k.run_schedulable
      else
        k.run_schedulable run_opts
      end
      
      OpenMailer.send_simple_html(self.success_email,"[VFI Track] Scheduled Job Succeeded",
          "Scheduled job for #{k.to_s} with options #{run_opts} has succeeded.").deliver! unless self.success_email.blank?
    rescue => e
      if self.failure_email.blank?
        # Log the error if no failure email is set.
        e.log_me ["Scheduled job for #{k.to_s} with options #{run_opts} has failed"]
      else
        OpenMailer.send_simple_html(self.failure_email,"[VFI Track] Scheduled Job Failed",
            "Scheduled job for #{k.to_s} with options #{run_opts} has failed. The error message is below:<br><br>
            #{e.message}").deliver!
      end
    end
  end

  def time_zone
    return ActiveSupport::TimeZone["Eastern Time (US & Canada)"] if self.time_zone_name.blank?
    tz = ActiveSupport::TimeZone[self.time_zone_name]
    raise "Invalid time zone name: #{self.time_zone_name}" if tz.nil?
    tz
  end

  def day_to_run
    self.day_of_month 
  end

  def hour_to_run
    self.run_hour
  end

  def minute_to_run
    self.run_minute
  end

  def sunday_active?
    self.run_sunday?
  end

  def monday_active?
    self.run_monday?
  end

  def tuesday_active?
    self.run_tuesday?
  end

  def wednesday_active?
    self.run_wednesday?
  end

  def thursday_active?
    self.run_thursday?
  end

  def friday_active?
    self.run_friday?
  end

  def saturday_active?
    self.run_saturday?
  end

  def interval
    self.run_interval
  end

  def allow_concurrency?
    # Be default, I want jobs to allow concurrency (.ie same job running at same time in different process), so the attribute is no_concurrent_jobs.
    !self.no_concurrent_jobs
  end

  private 
  def opts_hash
    return {} if self.opts.blank?
    JSON.parse self.opts
  end
end
