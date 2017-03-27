require 'open_chain/schedule_support'
class SchedulableJob < ActiveRecord::Base
  include OpenChain::ScheduleSupport
  attr_accessible :day_of_month, :opts, :run_class, :run_friday, :run_hour, :run_monday, :run_saturday, :run_sunday, :run_thursday,
    :run_tuesday, :run_wednesday, :time_zone_name, :run_minute, :last_start_time, :success_email, :failure_email, :run_interval, :no_concurrent_jobs, :running, :stopped

  def self.create_default_jobs!
    base_opts = {run_monday: true, run_tuesday: true, run_wednesday: true, run_thursday: true, run_friday: true, run_saturday: true, run_sunday: true}
    # Any "standard" schedulable job should be added here
    # If adding a new job, make sure to update the jobs array in the schedulable_job_spec
    SchedulableJob.where(run_class: "OpenChain::StatClient").first_or_create! base_opts.merge(run_interval: "4h", time_zone_name: "Eastern Time (US & Canada)")
    SchedulableJob.where(run_class: "OpenChain::IntegrationClient").first_or_create! base_opts.merge(run_interval: "1m", time_zone_name: "Eastern Time (US & Canada)", no_concurrent_jobs: true)
    SchedulableJob.where(run_class: "BusinessValidationTemplate").first_or_create! base_opts.merge(run_interval: "10m", time_zone_name: "Eastern Time (US & Canada)", no_concurrent_jobs: true)
    SchedulableJob.where(run_class: "SurveyResponseUpdate").first_or_create! base_opts.merge(run_interval: "1h", time_zone_name: "Eastern Time (US & Canada)")
    SchedulableJob.where(run_class: "OfficialTariff").first_or_create! base_opts.merge(run_interval: "12h", time_zone_name: "Eastern Time (US & Canada)", no_concurrent_jobs: true)
    SchedulableJob.where(run_class: "Message").first_or_create! base_opts.merge(run_hour: "23", run_minute: "0", time_zone_name: "Eastern Time (US & Canada)")
    SchedulableJob.where(run_class: "ReportResult").first_or_create! base_opts.merge(run_hour: "23", run_minute: "0", time_zone_name: "Eastern Time (US & Canada)")
    SchedulableJob.where(run_class: "OpenChain::WorkflowProcessor").first_or_create! base_opts.merge(run_interval: "5m", time_zone_name: "Eastern Time (US & Canada)", no_concurrent_jobs: true)
    SchedulableJob.where(run_class: "OpenChain::DailyTaskEmailJob").first_or_create! base_opts.merge(run_hour: '5', run_minute: '0', time_zone_name: "Eastern Time (US & Canada)")
    SchedulableJob.where(run_class: "OpenChain::LoadCountriesSchedulableJob").first_or_create! base_opts.merge(run_hour: '2', run_minute: '0', time_zone_name: "Eastern Time (US & Canada)")
    SchedulableJob.where(run_class: "OpenChain::Report::MonthlyUserAuditReport").first_or_create!({run_hour:'6',run_minute:'0',time_zone_name: "Eastern Time (US & Canada)",day_of_month:'1'})
    SchedulableJob.where(run_class: "OpenChain::BusinessRulesNotifier").first_or_create!({run_hour: '8', run_minute: '30', time_zone_name: "Eastern Time (US & Canada)"})
    SchedulableJob.where(run_class: "EntitySnapshotFailure").first_or_create! base_opts.merge(run_interval: "10m", time_zone_name: "Eastern Time (US & Canada)", no_concurrent_jobs: true)
  end

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
      # Opts Hash can technically be any json object, so protect the merge call below
      run_opts = opts_hash
      if run_opts.respond_to?(:merge)
        run_opts = {'last_start_time'=>self.last_start_time}.merge(run_opts)
      end
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
            #{e.message}".html_safe).deliver!
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
