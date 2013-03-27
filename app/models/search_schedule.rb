class SearchSchedule < ActiveRecord::Base
  RUFUS_TAG = "search_schedule"  

  belongs_to :search_setup
  belongs_to :custom_report

  def user
   return self.search_setup.user if self.search_setup
   return self.custom_report.user if self.custom_report
  end
  # get the next time in UTC that this schedule should be executed
  def next_run_time
    return Time.now.utc+1.day unless (self.day_of_month || run_day_set?) && !self.run_hour.nil?
    tz_str = user.time_zone
    tz_str = "Eastern Time (US & Canada)" if tz_str.blank?
    tz = ActiveSupport::TimeZone[tz_str]
    base_time = self.last_start_time.nil? ? self.created_at : self.last_start_time
    local_base_time = base_time.in_time_zone(tz_str)
    next_time_local = tz.local(local_base_time.year,local_base_time.month,local_base_time.day,self.run_hour)
    while next_time_local < local_base_time || !run_day?(next_time_local)
      next_time_local += 1.day
    end
    next_time_local.utc
  end
  #run the job if it should be run (next scheduled time < now & not already run by another thread)
  def run_if_needed log=nil
    if self.next_run_time < Time.now.utc
      update_count = SearchSchedule.where(:id=>self.id,:last_start_time=>self.last_start_time).update_all(["last_start_time = ?",Time.now])
      if update_count == 1
        self.run log
      end
    end
  end

  def run log=nil
    log.info "#{Time.now}: Search schedule #{self.id} starting." if log
    run_search self.search_setup, log if self.search_setup
    run_custom_report self.custom_report, log if self.custom_report
  end


  
  def is_running?
    if self.last_start_time.nil?
      return false
    elsif self.last_finish_time.nil?
      return true
    elsif self.last_start_time > self.last_finish_time
      return true
    else
      return false
    end
  end

  private

  def run_search srch_setup, log
    if !srch_setup.user.active?
      log.info "#{Time.now}: Search schedule #{self.id} stopped, user is locked." if log
      return
    end

    User.run_with_user_settings(srch_setup.user) do
      cm = CoreModule.find_by_class_name srch_setup.module_type
      extension = self.download_format.nil? || self.download_format.downcase=='csv' ? "csv" : "xls"
      attachment_name = "#{sanitize_filename(srch_setup.name)}.#{extension}"
      t = extension=="csv" ? write_csv(srch_setup) : write_xls(srch_setup)
      send_email srch_setup.name, t, attachment_name, log
      send_ftp srch_setup.name, t, attachment_name, log
      self.update_attributes(:last_finish_time => Time.now)
      log.info "#{Time.now}: Search schedule #{self.id} complete." if log
    end
    
  end

  def run_custom_report rpt, log
    if !rpt.user.active?
      log.info "#{Time.now}: Custom Report schedule #{self.id} stopped, user is locked." if log
      return
    end
    
    User.run_with_user_settings(rpt.user) do
      t = rpt.xls_file rpt.user
      attachment_name = "#{sanitize_filename(rpt.name)}.xls"
      send_email rpt.name, t, attachment_name, log
      send_ftp rpt.name, t, attachment_name, log
      self.update_attributes(:last_finish_time => Time.now)
      log.info "#{Time.now}: Search schedule #{self.id} complete." if log
    end
  end

  def write_csv srch_setup
    t = Tempfile.open(["scheduled_search_run",".csv"])
    t.write CsvMaker.new(:include_links=>srch_setup.include_links?,:no_time=>srch_setup.no_time?).make_from_search(srch_setup,srch_setup.search)
    t.close
    t 
  end

  def write_xls srch_setup
    t = Tempfile.new(["scheduled_search_run",".xls"])
    XlsMaker.new(:include_links=>srch_setup.include_links?,:no_time=>srch_setup.no_time?).make_from_search(srch_setup,srch_setup.search).write t
    t
  end

  def send_email name, temp_file,attachment_name, log=nil
    if !self.email_addresses.nil? && self.email_addresses.include?("@")
      log.info "#{Time.now}: Attempting to send email to #{self.email_addresses}" if log
      OpenMailer.send_search_result(self.email_addresses, name,attachment_name, temp_file.path).deliver!
      log.info "#{Time.now}: Sent email" if log
    end
  end

  def send_ftp name, temp_file, attachment_name, log=nil
    unless [self.ftp_server.blank?,
      self.ftp_username.blank?,
      self.ftp_password.blank?,
    ].include? true
      log.info "#{Time.now}: Attempting to send FTP to #{self.ftp_server}" if log
      opts = {:remote_file_name => attachment_name}
      opts[:folder] = self.ftp_subfolder unless self.ftp_subfolder.blank?
      begin
        FtpSender.send_file self.ftp_server, self.ftp_username, self.ftp_password, temp_file.path, opts
      rescue IOError => e
        #do email & internal message here
        log.error e.message if log
        search_name = (self.search_setup ? self.search_setup.name : self.custom_report.name)
        OpenMailer.send_search_fail(user.email,search_name,e.message,self.ftp_server,self.ftp_username,self.ftp_subfolder).deliver
        user.messages.create(:subject=>"Search Transmission Failure",:body=>"Search Name: #{search_name}\r"+
          "Server Name: #{self.ftp_server}\r"+
          "Account: #{self.ftp_username}\r"+
          "Subfolder: #{self.ftp_subfolder}\r"+
          "Error Message: #{e.message}")
        e.log_me ["FTP TO: #{self.ftp_server}","FTP USER: #{self.ftp_username}","FTP OPTS: #{opts}","User: #{user}"]
      end
      "#{Time.now}: FTP complete"
    end
  end
  

  def any_days_scheduled?
    self.run_sunday || 
    self.run_monday ||
    self.run_tuesday ||
    self.run_wednesday ||
    self.run_thursday || 
    self.run_friday ||
    self.run_saturday
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

  def run_day_set?
    self.run_sunday? || 
    self.run_monday? ||
    self.run_tuesday? || 
    self.run_wednesday? ||
    self.run_thursday? ||
    self.run_friday? ||
    self.run_saturday
  end
  #is the day of week for the given time a day that we should run the schedule
  def run_day? t
    if self.day_of_month
      return self.day_of_month == t.day
    end
    case t.wday
    when 0
      return self.run_sunday?
    when 1
      return self.run_monday?
    when 2
      return self.run_tuesday?
    when 3
      return self.run_wednesday?
    when 4
      return self.run_thursday?
    when 5
      return self.run_friday?
    when 6
      return self.run_saturday?
    end
  end

end
