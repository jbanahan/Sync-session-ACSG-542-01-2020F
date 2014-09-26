require 'open_chain/report'
require 'open_chain/report/xls_search'
class ReportResult < ActiveRecord::Base
  
  PURGE_WEEKS = 1 #purge all items older than this many weeks

  belongs_to :run_by, :class_name=>"User"
  belongs_to :custom_report
  has_attached_file :report_data,
    :path => "#{MasterSetup.get.uuid}/report_result/:id/:filename"
  before_create :sanitize
  before_post_process :no_post

  # Needs to run as lambda otherwise the purge at time stays at its initial value
  scope :eligible_for_purge, lambda { where('run_at < ?', PURGE_WEEKS.weeks.ago)}

  def self.run_schedulable
    purge
  end

  # Destroy all items eligible for purge
  def self.purge
    ReportResult.eligible_for_purge.destroy_all
  end

  # When should this ReportResult be purged from the database
  def purge_at
    self.run_at.nil? ? nil : (self.run_at + PURGE_WEEKS.weeks)
  end

  # Run a report.
  # report_name - Name of the report
  # user - User who ran the report
  # report_class- Class object for the report.  The underlying class needs to implement self.run_report(user,opts)
  # opts = report options hash like {:settings=>{'a'=>'b'},:friendly_settings=>['user friendly representation of the setttings hash']}
  def self.run_report! report_name, user, report_class, opts={}
    inner_opts = {:settings=>{},:friendly_settings=>[]}.merge(opts)
    rr = ReportResult.create!(:name=>report_name,:run_at=>0.seconds.ago,
      :friendly_settings_json=>inner_opts[:friendly_settings].to_json,:settings_json=>inner_opts[:settings].to_json,
      :report_class => report_class.to_s, :status=>"Queued", :run_by_id=>user.id, :custom_report_id=>inner_opts[:custom_report_id]
    )
    if report_class.respond_to?(:alliance_report?) && report_class.alliance_report?
      rr.delay(:priority=>100).execute_alliance_report
    else
      rr.delay(:priority=>100).execute_report
    end
    
  end

  def can_view? u
    u.sys_admin? || u==self.run_by
  end

  # Set the friendly settings (creates the underlying json for you)
  def friendly_settings= settings_array
    if settings_array.nil?
      self.friendly_settings_json = nil
    else 
      self.friendly_settings_json = settings_array.to_json
    end
  end

  # Get the friendly settings which are ok to show directly to the user from the underlying json
  def friendly_settings
    self.friendly_settings_json ? ActiveSupport::JSON.decode(self.friendly_settings_json) : []
  end

  def execute_report
    User.run_with_user_settings(run_by) do
      self.update_attributes(:status=>"Running")
      local_path = nil
      begin
        local_file = nil
        if self.custom_report_id.nil?
          local_file = self.report_class.constantize.run_report run_by, ActiveSupport::JSON.decode(self.settings_json)
        else
          local_file = self.custom_report.run_report run_by
        end
        complete_report local_file
      rescue => err
        fail_report err
      ensure
        file_cleanup local_file
      end
    end
  end

  def execute_alliance_report
    User.run_with_user_settings(run_by) do
      self.update_attributes(:status=>"Running")
      settings = ActiveSupport::JSON.decode(self.settings_json)
      self.report_class.constantize.run_report run_by, settings.merge('report_result_id' => self.id)
    end
  rescue => e
    fail_report e
  end

  def continue_alliance_report results
    User.run_with_user_settings(run_by) do
      local_file = nil
      begin
        self.update_attributes(:status=>"Running")
        settings = ActiveSupport::JSON.decode(self.settings_json)
        results = results.is_a?(String) ? ActiveSupport::JSON.decode(results) : results
        local_file = self.report_class.constantize.process_alliance_query_details run_by, results, settings
        complete_report local_file
      rescue => err
        fail_report err
      ensure 
        file_cleanup local_file        
      end
    end
  end

  def file_cleanup local_file
    return unless local_file

    # There appears to be a bug with closing a File object and then calling File.exists?
    # (currently raising IOError: closed stream - doesn't on different ruby versions (.ie jruby))
    # So just work around it.
    if local_file.is_a? Tempfile
      local_file.close!
    else
      if File.exists?(local_file)
        local_file.close if local_file.respond_to?(:close) && !local_file.closed?
        File.delete(local_file)
      end
    end
    nil
  end

  def complete_report local_file
    self.report_data = local_file
    self.status = "Complete"
    self.save
    run_by.messages.create(:subject=>"Report Complete: #{name}",:body=>"<p>Your report has completed.</p>
<p>You can download it by clicking <a href='#{Rails.application.routes.url_helpers.download_report_result_url(host: MasterSetup.get.request_host, id: id, protocol: (Rails.env.development? ? "http" : "https"))}'>here</a>.</p>
<p>You can view the report status page by clicking <a href='#{report_results_link}'>here</a>.</p>"
    )
  end

  def fail_report e
    self.update_attributes(:status=>"Failed",:run_errors=>e.message)
    run_by.messages.create(:subject=>"Report FAILED: #{name}",:body=>"<p>Your report failed to run properly.</p>
<p>You can view the error on the report status page by clicking <a href='#{report_results_link}'>here</a>.</p>
<p>If you need immediate support, please click the Help link at the top of the screen and log a new incident.</p>")
  end

  def report_results_link
    # Use url instead of path because user messages can be emailed.
    Rails.application.routes.url_helpers.report_result_url(host: MasterSetup.get.request_host, id: id, protocol: (Rails.env.development? ? "http" : "https"))
  end

  def report_content
    return nil unless report_data.path
    OpenChain::S3.get_data report_data.options[:bucket], report_data.path
  end

  def secure_url(expires_in=10.seconds)
    OpenChain::S3.url_for report_data.options[:bucket], report_data.path, expires_in
  end

  private
  def no_post
    false
  end
  
  def sanitize
    Attachment.sanitize_filename self, :report_data
  end

end
