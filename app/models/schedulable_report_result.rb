# This class exists pretty much solely because report result already has a run_schedulable method
# associated with it which does report result purges.
class SchedulableReportResult < ReportResult

  def self.run_schedulable opts = {}
    opts = opts.with_indifferent_access
    user, report_name, report_class, settings = parse_required_opts opts
    
    # Merge settings from report schedule setup with any settings returned by the classes schedulable_settings' method
    if opts['settings'] && settings['settings']
      # Settings from the json setup should win over ones from the report's schedulable_settings method
      opts['settings'] = settings['settings'].merge opts['settings']
    elsif settings['settings']
      opts['settings'] = settings['settings']
    end

    if opts['friendly_settings'] && settings['friendly_settings']
      opts['friendly_settings'].push *Array.wrap(settings['friendly_settings'])
      opts['friendly_settings'].uniq!
    elsif settings['friendly_settings']
      opts['friendly_settings'] = settings['friendly_settings']
    end

    run_report! report_name, user, report_class, opts.with_indifferent_access
  end

  def self.parse_required_opts opts
    user = opts['username'].blank? ? nil : User.where(username: opts['username']).first
    raise "username option must be set and point to an existing user." unless user

    report_name = opts["report_name"]
    raise "report_name option must be set." if report_name.blank?

    report_class = opts["report_class"]
    settings = {}

    if !report_class.blank?
      rc = nil
      begin
        rc = report_class.to_s.constantize
      rescue
        report_class = nil
      end

      raise "report_class #{report_class} must implement the run_report method." unless rc.nil? || rc.respond_to?(:run_report)
      
      if rc.respond_to?(:schedulable_settings)
        settings = rc.schedulable_settings(user, report_name, opts).with_indifferent_access
      end

      if rc.respond_to?(:permission?)
        raise "User #{user.username} does not have permission to run this scheduled report." unless rc.permission?(user)
      end

      if rc.respond_to?(:can_view?)
        raise "User #{user.username} does not have permission to run this scheduled report." unless rc.can_view?(user)
      end
    end

    raise "report_class option must be set to a valid report class." if report_class.blank?
    [user, report_name, report_class, settings]
  end

end