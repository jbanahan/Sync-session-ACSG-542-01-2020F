class SearchSchedule < ActiveRecord::Base
  RUFUS_TAG = "search_schedule"  

  belongs_to :search_setup

  #reload all SearchSchedules within the given scheduler
  def self.reset_schedule scheduler, log=nil
    begin
    log.info "#{Time.now}: Resetting Scheduled Jobs" if log
    #unschedule all jobs
    jobs = scheduler.find_by_tag(RUFUS_TAG) 
    log.info "#{Time.now}: #{jobs.length} jobs to be removed." if log
    jobs.each {|job| 
      log.info "#{Time.now}: Removing job #{job.job_id}" if log
      scheduler.unschedule job.job_id
    }
    #schedule all
    SearchSchedule.all.each {|ss| ss.schedule scheduler, log}
    rescue Exception => e
      if log
        log.error e.message
      else
        raise e
      end
    end
  end

  def run log=nil
    log.info "#{Time.now}: Search schedule #{self.id} starting." if log
    srch_setup = self.search_setup
    cm = CoreModule.find_by_class_name srch_setup.module_type
    extension = self.download_format.nil? || self.download_format.downcase=='csv' ? "csv" : "xls"
    attachment_name = "#{sanitize_filename(srch_setup.name)}.#{extension}"
    t = extension=="csv" ? write_csv(srch_setup) : write_xls(srch_setup)
    send_email srch_setup.name, t, attachment_name, log
    send_ftp srch_setup.name, t, attachment_name, log
    log.info "#{Time.now}: Search schedule #{self.id} complete." if log
  end

  def schedule(scheduler, log=nil)
    begin
      cs = cron_string
      log.info "#{Time.now}: Attempting to schedule job for Schedule #{self.id}, with cron \"#{cs}" if log
      scheduler.cron cs, {:tags=> RUFUS_TAG} { SearchSchedule.find(self.id).run log } if any_days_scheduled? && self.run_hour
      log.info "#{Time.now}: Scheduled job for Schedule #{self.id}, with cron \"#{cs}\"" if log
    rescue StandardError => e
      if log
        log.error e
      else
        raise e
      end
    end
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

  def write_csv srch_setup
    t = Tempfile.open("scheduled_search_run")
    t.write CsvMaker.new.make(srch_setup,srch_setup.search)
    t.close
    t 
  end

  def write_xls srch_setup
    t = Tempfile.new("scheduled_search_run")
    XlsMaker.new.make(srch_setup,srch_setup.search).write t
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
        user = self.search_setup.user
        OpenMailer.send_search_fail(user.email,self.search_setup.name,e.message,self.ftp_server,self.ftp_username,self.ftp_subfolder).deliver
        user.messages.create(:subject=>"Search Transmission Failure",:body=>"Search Name: #{self.search_setup.name}\r"+
          "Server Name: #{self.ftp_server}\r"+
          "Account: #{self.ftp_username}\r"+
          "Subfolder: #{self.ftp_subfolder}\r"+
          "Error Message: #{e.message}")
      end
      "#{Time.now}: FTP complete"
    end
  end
  
  def cron_string
    return nil unless any_days_scheduled?
    tz = search_setup.user.time_zone.nil? ? "America/New_York" : ActiveSupport::TimeZone::MAPPING[search_setup.user.time_zone]
    "0 #{run_hour} * * #{make_days_of_week} #{tz}"
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

end
