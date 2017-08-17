require 'open_chain/schedule_support'
require 'open_chain/email_validation_support'

class SearchSchedule < ActiveRecord::Base
  include OpenChain::ScheduleSupport
  include OpenChain::EmailValidationSupport

  RUFUS_TAG = "search_schedule"  

  belongs_to :search_setup
  belongs_to :custom_report

  def user
   return self.search_setup.user if self.search_setup
   return self.custom_report.user if self.custom_report
  end
  
  # get the time zone to consider for the user
  def time_zone
    tz_str = user.time_zone
    tz_str = "Eastern Time (US & Canada)" if tz_str.blank?
    tz = ActiveSupport::TimeZone[tz_str]
  end

  def run log=nil
    log.info "#{Time.now}: Search schedule #{self.id} starting." if log
    run_search self.search_setup, log if self.search_setup
    run_custom_report self.custom_report, log if self.custom_report
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

  def send_email name, temp_file,attachment_name, user, log=nil
    unless self.email_addresses.blank?  
      log.info "#{Time.now}: Attempting to send email to #{self.email_addresses}" if log
      if email_list_valid? self.email_addresses
        OpenMailer.send_search_result(self.email_addresses, name, attachment_name, temp_file.path, user).deliver!
      else
        msg = "The above scheduled search contains an invalid email address. Please correct it and try again."
        OpenMailer.send_search_bad_email(user.email, self.search_setup, msg).deliver!
      end
      log.info "#{Time.now}: Sent email" if log
    end
  end

  private

  def timestamp
    exclude_file_timestamp ? "" : Time.zone.now.strftime("_%Y%m%d%H%M%S%L")
  end

  def run_search srch_setup, log
    if !srch_setup.user.active?
      log.info "#{Time.now}: Search schedule #{self.id} stopped, user is locked." if log
      return
    end
    User.run_with_user_settings(srch_setup.user) do
      extension = self.download_format.nil? || self.download_format.downcase=='csv' ? "csv" : "xls"
      attachment_name = "#{sanitize_filename(srch_setup.name)}#{timestamp}.#{extension}"
      Tempfile.open(["scheduled_search_run", ".#{extension}"]) do |t|
        t.binmode
        if extension == "csv"
         report_has_data = write_csv(srch_setup, t) 
        else 
         report_has_data = write_xls(srch_setup, t)
        end
        
        if send_if_empty? || report_has_data
          send_email srch_setup.name, t, attachment_name, srch_setup.user, log
          send_ftp srch_setup.name, t, attachment_name, log
        end
        self.update_attributes(:last_finish_time => Time.now)
        log.info "#{Time.now}: Search schedule #{self.id} complete." if log
      end
    end
  rescue => e
    e.log_me
    send_error_to_user user, e.message
  end

  def run_custom_report rpt, log
    if !rpt.user.active?
      log.info "#{Time.now}: Custom Report schedule #{self.id} stopped, user is locked." if log
      return
    end
    
    User.run_with_user_settings(rpt.user) do
      t = nil
      attachment_name = "#{sanitize_filename(rpt.name)}#{timestamp}"

      if self.download_format.nil? || self.download_format.downcase=='csv'
        t = rpt.csv_file rpt.user
        attachment_name = "#{attachment_name}.csv"
      else
        t = rpt.xls_file rpt.user
        attachment_name = "#{attachment_name}.xls"
      end
      
      if send_if_empty? || !report_blank?(t)
        send_email rpt.name, t, attachment_name, rpt.user, log
        send_ftp rpt.name, t, attachment_name, log
      end
      self.update_attributes(:last_finish_time => Time.now)
      log.info "#{Time.now}: Search schedule #{self.id} complete." if log
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

  def write_csv srch_setup, t
    m, result_count = CsvMaker.new(:include_links=>srch_setup.include_links?,:no_time=>srch_setup.no_time?).make_from_search_query SearchQuery.new(srch_setup, srch_setup.user)
    results = result_count > 0
    t.write m
    t.flush
    
    results
  end

  def write_xls srch_setup, t
    m, result_count = XlsMaker.new(:include_links=>srch_setup.include_links?,:no_time=>srch_setup.no_time?).make_from_search_query SearchQuery.new(srch_setup, srch_setup.user)
    results = result_count > 0
    m.write t
    t.flush
    
    results
  end

  def send_ftp name, temp_file, attachment_name, log=nil
    unless [self.ftp_server.blank?,
      self.ftp_username.blank?,
      self.ftp_password.blank?,
    ].include? true
      protocol = self.protocol.blank? ? "FTP" : self.protocol.upcase

      log.info "#{Time.now}: Attempting to send #{protocol} to #{self.ftp_server}" if log
      opts = {:remote_file_name => attachment_name}
      opts[:folder] = self.ftp_subfolder unless self.ftp_subfolder.blank?
      opts[:protocol] = self.protocol unless self.protocol.blank?
      begin
        FtpSender.send_file self.ftp_server, self.ftp_username, self.ftp_password, temp_file.path, opts
      rescue IOError => e
        #do email & internal message here
        # The FtpSender already logs all errors emanating from it, and automatically retries to send so there's no point in calling log_me on the error again here
        log.error e.message if log
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
  def sanitize_filename(filename)
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
