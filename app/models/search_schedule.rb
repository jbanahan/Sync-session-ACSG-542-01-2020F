# == Schema Information
#
# Table name: search_schedules
#
#  created_at             :datetime         not null
#  custom_report_id       :integer
#  day_of_month           :integer
#  disabled               :boolean
#  download_format        :string(255)
#  email_addresses        :string(255)
#  exclude_file_timestamp :boolean
#  ftp_password           :string(255)
#  ftp_port               :string(255)
#  ftp_server             :string(255)
#  ftp_subfolder          :string(255)
#  ftp_username           :string(255)
#  id                     :integer          not null, primary key
#  last_finish_time       :datetime
#  last_start_time        :datetime
#  protocol               :string(255)
#  report_failure_count   :integer          default(0)
#  run_friday             :boolean
#  run_hour               :integer
#  run_monday             :boolean
#  run_saturday           :boolean
#  run_sunday             :boolean
#  run_thursday           :boolean
#  run_tuesday            :boolean
#  run_wednesday          :boolean
#  search_setup_id        :integer
#  send_if_empty          :boolean
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_search_schedules_on_custom_report_id  (custom_report_id)
#  index_search_schedules_on_search_setup_id   (search_setup_id)
#

require 'open_chain/schedule_support'
require 'open_chain/email_validation_support'

class SearchSchedule < ActiveRecord::Base
  include OpenChain::ScheduleSupport
  include OpenChain::EmailValidationSupport

  RUFUS_TAG = "search_schedule"  

  belongs_to :search_setup
  belongs_to :custom_report

  def user
    if self.search_setup
      return self.search_setup.user
    elsif self.custom_report
      return self.custom_report.user
    else
      nil
    end
  end
  
  # get the time zone to consider for the user
  def time_zone
    tz_str = user.time_zone
    tz_str = "Eastern Time (US & Canada)" if tz_str.blank?
    tz = ActiveSupport::TimeZone[tz_str]
  end

  def run
    if self.search_setup
      run_search(self.search_setup)
    elsif self.custom_report
      run_custom_report(self.custom_report)
    end
  end

  # Prevents the scheduled search or custom report from running if it has been disabled or if the user associated with
  # it has been deactivated.
  def stopped?
    self.disabled? || (!self.search_setup.nil? && !self.search_setup.user.active?) || (!self.custom_report.nil? && !self.custom_report.user.active?)
  end

  def day_to_run
    self.day_of_month 
  end

  def hour_to_run
    self.run_hour
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

  def send_email name, temp_file,attachment_name, user
    unless self.email_addresses.blank?
      if email_list_valid? self.email_addresses
        OpenMailer.send_search_result(self.email_addresses, name, attachment_name, temp_file.path, user).deliver!
      else
        msg = "The above scheduled search contains an invalid email address. Please correct it and try again."
        OpenMailer.send_search_bad_email(user.email, self.search_setup, msg).deliver!
      end
    end
  end

  def self.report_name search_setup, file_extension, include_timestamp: false
    name = sanitize_filename(search_setup.name)
    if include_timestamp
      name += Time.zone.now.strftime("_%Y%m%d%H%M%S%L")
    end

    name += ".#{file_extension}"
  end

  private

  def run_search srch_setup
    User.run_with_user_settings(srch_setup.user) do
      # Make sure we're using the output format designated in the search schedule, not the search_setup
      sw = SearchWriter.new search_setup, output_format: self.download_format

      Tempfile.open(["scheduled_search_run", ".#{sw.output_format}"]) do |tempfile|
        tempfile.binmode
        begin
          result_count = sw.write_search tempfile
          tempfile.rewind

          if result_count > 0 || send_if_empty?
            attachment_name = self.class.report_name srch_setup, sw.output_format, include_timestamp: !exclude_file_timestamp
      
            send_email srch_setup.name, tempfile, attachment_name, srch_setup.user
            send_ftp srch_setup.name, tempfile, attachment_name
          end

          self.update_attributes!(:last_finish_time => Time.now, :report_failure_count => 0)
        rescue SearchExceedsMaxResultsError
          failure_count = (self.report_failure_count.to_i + 1)
          disabled = (failure_count >= 5)
          self.update_attributes! report_failure_count: failure_count, disabled: disabled
          
          send_excessive_size_failure_email user, disabled
        end
      end
    end
  rescue => e
    e.log_me
    send_error_to_user user, e.message
  end

  def run_custom_report rpt
    User.run_with_user_settings(rpt.user) do
      t = nil
      extension = self.download_format.nil? || self.download_format.downcase=='csv' ? "csv" : "xls"
      attachment_name = self.class.report_name rpt, extension, include_timestamp: !exclude_file_timestamp

      begin      
        if extension=='csv'
          t = rpt.csv_file rpt.user
        else
          t = rpt.xls_file rpt.user
        end

        if send_if_empty? || !report_blank?(t)
          send_email rpt.name, t, attachment_name, rpt.user
          send_ftp rpt.name, t, attachment_name
        end
        self.update_attributes(:last_finish_time => Time.now)
      ensure
        t.close! unless t.nil? || t.closed?
      end
    end
  end

  #For custom reports. Searches can use return value of #write_csv, #write_xls
  def report_blank? report_file
    File.extname(report_file) == '.csv' ? csv_report_blank?(report_file) : xls_report_blank?(report_file)
  end

  def csv_report_blank? report_file
    csv_report = CSV.read(report_file)
    return true if csv_report.count == 1
    if csv_report.count == 2   
      (csv_report[1][0] =~ /No data was returned/).nil?  ? false : true
    else false
    end
  end

  def xls_report_blank? report_file
    xls_report = Spreadsheet.open(report_file).worksheet 0
    return true if xls_report.count == 1
    if xls_report.count == 2
      (xls_report.row(1)[0] =~ /No data was returned/).nil? ? false : true
    else false
    end
  end

  def send_ftp name, temp_file, attachment_name
    unless [self.ftp_server.blank?,
      self.ftp_username.blank?,
      self.ftp_password.blank?,
    ].include? true
      protocol = self.protocol.blank? ? "FTP" : self.protocol.upcase

      opts = {:remote_file_name => attachment_name}
      opts[:folder] = self.ftp_subfolder unless self.ftp_subfolder.blank?
      opts[:protocol] = self.protocol unless self.protocol.blank?
      opts[:port] = ftp_port.blank? ? nil : ftp_port
      begin
        FtpSender.send_file self.ftp_server, self.ftp_username, self.ftp_password, temp_file.path, opts
      rescue IOError => e
        #do email & internal message here
        # The FtpSender already logs all errors emanating from it, and automatically retries to send so there's no point in calling log_me on the error again here
        search_name = (self.search_setup ? self.search_setup.name : self.custom_report.name)
        OpenMailer.send_search_fail(user.email,search_name,e.message,self.ftp_server,self.ftp_username,self.ftp_subfolder).deliver
        add_info = ["Protocol: #{protocol}", "Server Name: #{self.ftp_server}", "Account: #{self.ftp_username}", "Subfolder: #{self.ftp_subfolder}"]
        send_error_to_user user, e.message, add_info
      end
      "#{Time.now}: #{protocol} complete"
    end
  end

  def send_error_to_user user, error_message, additional_lines = []
    search_name = (self.search_setup ? self.search_setup.name : self.custom_report.name)
    message_body = "Search Name: #{search_name}"
    if additional_lines.length > 0
      message_body += "<br>#{additional_lines.join("<br>")}"
    end
    message_body += "<br>Error Message: #{error_message}"

    user.messages.create!(subject: "Search Transmission Failure", body: message_body)
  end

  def send_excessive_size_failure_email user, disable_threshold_reached
    search_name = (self.search_setup ? self.search_setup.name : self.custom_report.name)
    if disable_threshold_reached
      subject = "Scheduled Report '#{search_name}' was DISABLED"
      body = "Your Scheduled Report '#{search_name}' was DISABLED because the file output was too large to process on five or more consecutive attempts.  To re-enable the report, please adjust the Scheduled Report parameters in VFI Track to reduce its output size, then clear the 'Disabled?' box in the Scheduled Report set-up section to resume running the report."
    else
      subject = "Scheduled Report '#{search_name}' failed"
      body = "Your Scheduled Report '#{search_name}' failed because the file output was too large to process.  Please adjust the Scheduled Report parameters to reduce its output size.  Your report has failed #{self.report_failure_count} time#{(self.report_failure_count > 1 ? "s in a row" : "")}.  On the 5th consecutive failure, VFI Track will disable the report."
    end
    OpenMailer.send_simple_html(user.email, subject, body).deliver!
  end

  def make_days_of_week
    d = []
    d << "0" if self.run_sunday
    d << "1" if self.run_monday
    d << "2" if self.run_tuesday
    d << "3" if self.run_wednesday
    d << "4" if self.run_thursday
    d << "5" if self.run_friday
    d << "6" if self.run_saturday

    return CSV.generate_line(d,{:row_sep=>""})
  end

  def self.sanitize_filename(filename)
    filename.strip.tap do |name|
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      name.sub! /\A.*(\\|\/)/, ''
      # Finally, replace all non alphanumeric, underscore
      # or periods with underscore
      name.gsub! /[^\w\.\-]/, '_'
    end
  end

end
