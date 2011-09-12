class ReportResult < ActiveRecord::Base
  belongs_to :run_by, :class_name=>"User"
  has_attached_file :report_data,
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_permissions => :private,
    :path => "#{MasterSetup.get.uuid}/report_result/:id/:filename",
    :bucket => 'chain-io'
  before_post_process :no_post


  # Run a report.
  # report_name - Name of the report
  # user - User who ran the report
  # report_class- Class object for the report.  The underlying class needs to implement self.run_report(user,opts)
  # opts = report options hash like {:settings=>{'a'=>'b'},:friendly_settings=>['user friendly representation of the setttings hash']}
  def self.run_report! report_name, user, report_class, opts={}
    inner_opts = {:settings=>{},:friendly_settings=>[]}.merge(opts)
    rr = ReportResult.create!(:name=>report_name,:run_at=>0.seconds.ago,
      :friendly_settings_json=>inner_opts[:friendly_settings].to_json,:settings_json=>inner_opts[:settings].to_json,
      :report_class => report_class.to_s, :status=>"Queued", :run_by_id=>user.id
    )
    rr.execute_report
  end

  def can_view? u
    u.sys_admin? || u==self.run_by
  end

  def execute_report
    self.update_attributes(:status=>"Running")
    local_path = nil
    begin
      local_path = Kernel.const_get(self.report_class).run_report run_by, ActiveSupport::JSON.decode(self.settings_json)
      self.report_data = File.new(local_path)
      self.status = "Complete"
      self.save
      run_by.messages.create(:subject=>"Report Complete: #{name}",:body=>"<p>Your report has completed.</p>
<p>You can download it by clicking <a href='/report_results/#{self.id}/download'>here</a>.</p>"
      )
    rescue
      $!.log_me ["Report execution failure.","User: #{self.run_by.full_name}","ReportResultID: #{self.id}"]
      self.update_attributes(:status=>"Failed",:run_errors=>$!.message)
      run_by.messages.create(:subject=>"Report FAILED: #{name}",:body=>"<p>Your report failed to run properly.</p>
<p>If you need immediate support, please click the Help link at the top of the screen and log a new incident.</p>")
    ensure
      File.delete local_path if local_path && File.exists?(local_path)
    end
  end

  def report_content
    return nil unless report_data.path
    retries = 0
    begin
      uri = URI.parse(AWS::S3::S3Object.url_for report_data.path, report_data.options[:bucket], {:expires_in => 2.minutes, :use_ssl => true})
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.request(Net::HTTP::Get.new(uri.request_uri))
      response.body
    rescue
      retries+=1
      retry if retries < 3
      raise "File data could not be retrieved from the database."
    end
  end

  private
  def no_post
    false
  end

end
