# == Schema Information
#
# Table name: report_results
#
#  created_at               :datetime         not null
#  custom_report_id         :integer
#  email_to                 :string(255)
#  friendly_settings_json   :text
#  id                       :integer          not null, primary key
#  name                     :string(255)
#  report_class             :string(255)
#  report_data_content_type :string(255)
#  report_data_file_name    :string(255)
#  report_data_file_size    :integer
#  report_data_updated_at   :datetime
#  run_at                   :datetime
#  run_by_id                :integer
#  run_errors               :text
#  settings_json            :text
#  status                   :string(255)
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_report_results_on_custom_report_id  (custom_report_id)
#  index_report_results_on_run_by_id         (run_by_id)
#

# This class exists pretty much solely because report result already has a run_schedulable method
# associated with it which does report result purges.
class SchedulableReportResult < ReportResult
  attr_accessible :custom_report_id, :email_to, :friendly_settings_json, :name, :report_class, :report_data_content_type, :report_data_file_name, :report_data_file_size, :report_data_updated_at, :run_at, :run_by_id, :run_errors, :settings_json, :status

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

    settings = {}
    report_class = nil
    if !opts["report_class"].blank?
      begin
        report_class = opts["report_class"].to_s.constantize
      rescue
        raise "report_class option must be set to a valid report class."
      end

      raise "report_class #{opts["report_class"]} must implement the run_report method." unless report_class.respond_to?(:run_report)
      
      if report_class.respond_to?(:schedulable_settings)
        settings = report_class.schedulable_settings(user, report_name, opts).with_indifferent_access
      end

      if report_class.respond_to?(:permission?)
        raise "User #{user.username} does not have permission to run this scheduled report." unless report_class.permission?(user)
      end

      if report_class.respond_to?(:can_view?)
        raise "User #{user.username} does not have permission to run this scheduled report." unless report_class.can_view?(user)
      end
    else
      raise "report_class option must be set to a valid report class."
    end

    [user, report_name, report_class, settings]
  end

end
