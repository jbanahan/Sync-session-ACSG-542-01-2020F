# == Schema Information
#
# Table name: report_results
#
#  created_at               :datetime         not null
#  custom_report_id         :integer
#  email_to                 :string(255)
#  friendly_settings_json   :text(65535)
#  id                       :integer          not null, primary key
#  name                     :string(255)
#  report_class             :string(255)
#  report_data_content_type :string(255)
#  report_data_file_name    :string(255)
#  report_data_file_size    :integer
#  report_data_updated_at   :datetime
#  run_at                   :datetime
#  run_by_id                :integer
#  run_errors               :text(65535)
#  settings_json            :text(65535)
#  status                   :string(255)
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_report_results_on_custom_report_id  (custom_report_id)
#  index_report_results_on_run_by_id         (run_by_id)
#

require 'open_chain/report'
require 'open_chain/report/async_search'

class ReportResult < ActiveRecord::Base
  
  PURGE_WEEKS = 1 #purge all items older than this many weeks

  attr_accessible :created_at, :custom_report_id, :email_to,
    :friendly_settings_json, :name, :report_class,
    :report_data_file_size, :report_data_content_type, 
    :report_data_file_name, :report_data_updated_at, :run_at,
    :run_by_id, :run_errors, :settings_json, :status, :updated_at

  belongs_to :run_by, :class_name=>"User"
  belongs_to :custom_report
  has_attached_file :report_data, :path => ":master_setup_uuid/report_result/:id/:filename"
  # Paperclip, as of v4, forces you to list all the attachment types you allow to be uploaded.  We don't restrict these
  # at all, so this disables that validation.
  do_not_validate_attachment_file_type :report_data
  
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
    inner_opts = {:settings=>{},:friendly_settings=>[]}.with_indifferent_access.merge(opts)
    rr = ReportResult.create!(:name=>report_name,:run_at=>0.seconds.ago,
      :friendly_settings_json=>inner_opts[:friendly_settings].to_json,:settings_json=>inner_opts[:settings].to_json,
      :report_class => report_class.to_s, :status=>"Queued", :run_by_id=>user.id, :custom_report_id=>inner_opts[:custom_report_id], email_to: inner_opts[:email_to]
    )
    # The lower the priority the quicker dj picks these up from the queue - we want these done right away since they're user init'ed.
    if report_class.respond_to?(:sql_proxy_report?) && report_class.sql_proxy_report?
      rr.delay(:priority=>-1).execute_sql_proxy_report
    else
      rr.delay(:priority=>-1).execute_report
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
        block_utilized = false
        if self.custom_report_id.nil?
          # Allow for the implementing class to take a block, and then yield the report tempfile...if the class doesn't take 
          # a block, then it's expected the class returns a tempfile of the report output.

          # This allows for the report to use the block style tempfile handling and yield the tempfile back to us here while in the
          # block, thus utilizing the ruby native file closing support..and not having to rely on our own.
          local_file = self.report_class.constantize.run_report(run_by, ActiveSupport::JSON.decode(self.settings_json)) do |tempfile|
            block_utilized = true
            complete_report(tempfile)
          end
        else
          local_file, * = self.custom_report.run_report(run_by) do |tempfile|
            block_utilized = true
            complete_report(tempfile)
          end
        end
        complete_report(local_file) unless block_utilized
      rescue => err
        fail_report err
      ensure
        file_cleanup local_file
      end
    end
  end

  def execute_sql_proxy_report
    User.run_with_user_settings(run_by) do
      self.update_attributes(:status=>"Running")
      settings = ActiveSupport::JSON.decode(self.settings_json)
      self.report_class.constantize.run_report run_by, settings.merge('report_result_id' => self.id)
    end
  rescue => e
    fail_report e
  end

  def continue_sql_proxy_report results
    User.run_with_user_settings(run_by) do
      local_file = nil
      begin
        self.update_attributes(:status=>"Running")
        settings = ActiveSupport::JSON.decode(self.settings_json)
        results = results.is_a?(String) ? ActiveSupport::JSON.decode(results) : results
        local_file = self.report_class.constantize.process_sql_proxy_query_details run_by, results, settings
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

    # There appears to be a bug with closing a File object and then calling File.exist?
    # (currently raising IOError: closed stream - doesn't on different ruby versions (.ie jruby))
    # So just work around it.
    if local_file.is_a? Tempfile
      local_file.close!
    else
      if File.exist?(local_file)
        local_file.close if local_file.respond_to?(:close) && !local_file.closed?
        File.delete(local_file)
      end
    end
    nil
  end

  def complete_report local_file
    self.report_data = local_file
    self.status = "Complete"
    self.save!

    if !self.email_to.blank?
      OpenMailer.send_simple_html(self.email_to, "Report Complete: #{name}", "Attached is the completed report named #{name}.", [local_file]).deliver_now
    else
      run_by.messages.create(:subject=>"Report Complete: #{name}",:body=>"<p>Your report has completed.</p>
        <p>You can download it by clicking <a href='#{Rails.application.routes.url_helpers.download_report_result_url(host: MasterSetup.get.request_host, id: id, protocol: (Rails.env.development? ? "http" : "https"))}'>here</a>.</p>
        <p>You can view the report status page by clicking <a href='#{report_results_link}'>here</a>.</p>"
      )
    end
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
