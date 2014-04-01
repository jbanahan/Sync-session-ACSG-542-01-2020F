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

  scope :eligible_for_purge, where('run_at < ?',PURGE_WEEKS.weeks.ago)

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
    rr.delay(:priority=>100).execute_report
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
        self.report_data = local_file
        self.status = "Complete"
        self.save
        run_by.messages.create(:subject=>"Report Complete: #{name}",:body=>"<p>Your report has completed.</p>
<p>You can download it by clicking <a href='/report_results/#{self.id}/download'>here</a>.</p>
<p>You can view the report status page by clicking <a href='/report_results/#{self.id}'>here</a>.</p>"
        )
      rescue
        $!.log_me ["Report execution failure.","User: #{self.run_by.full_name}","ReportResultID: #{self.id}"]
        self.update_attributes(:status=>"Failed",:run_errors=>$!.message)
        run_by.messages.create(:subject=>"Report FAILED: #{name}",:body=>"<p>Your report failed to run properly.</p>
<p>If you need immediate support, please click the Help link at the top of the screen and log a new incident.</p>")
      ensure
        File.delete local_file if local_file && File.exists?(local_file)
      end
    end
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
