require 'net/ftp'

module OpenChain
  class IsfMonitor
    def self.run_schedulable opts = {}
      hostname = opts['hostname']
      username = opts['username']
      password = opts['password']
      directory = opts['directory']
      minutes_to_check = opts['duration'].to_i
      timezone = opts['server_timezone']

      raise "hostname, username, password and directory must be passed in" if hostname.blank? || username.blank? || password.blank? || directory.blank?

      self.new.run(hostname, username, password, directory, minutes_to_check, timezone)
    end

    def run(hostname, username, password, directory, minutes_to_check, timezone)
      data = find_backed_up_files(hostname, username, password, directory, minutes_to_check, timezone)

      if !data.blank?
        to = MailingList.where(system_code: "ISF Monitor").first.presence || "support@vandegriftinc.com"
        subject = "ISF Processing Stuck"
        OpenMailer::send_simple_html(to, subject, email_body(data)).deliver!
      end
    end

    def email_body data
      body = "<p>Kewill EDI ISF processing is delayed. The oldest file in the folder is from #{data[:oldest_file_date].strftime("%m/%d/%Y %H:%M %Z")} and there are #{data[:file_count]} files in the folder.</p>"
      body += "<p>Use the following Freshservice solution to troubleshoot this problem: <a href='https://vandegrift.freshservice.com/solution/articles/4000017674-isf-processing-stuck-warnings'>ISF Processing Stuck Warnings</a></p>"
      body += "<p>Below is a listing of all unprocessed files currently in the folder:<br><pre>"
      Array.wrap(data[:directory_list]).each do |row|
        body += (row.to_s + "\n")
      end
      body += "</pre></p>"

      body.html_safe
    end

    def find_backed_up_files hostname, username, password, directory, minutes_to_check, timezone
      ftp = ftp_connection(hostname)
      ftp_login(ftp, username, password)
      ftp_chdir(ftp, directory)
      contents = ftp.nlst
      debug_info = ftp.list

      return nil unless contents.present?

      file_dates = process_ftp_contents(ftp, contents, timezone)
      oldest_est_date = utc_to_est_date(file_dates[0])

      if is_backed_up?(file_dates[0], minutes_to_check)
        return {oldest_file_date: oldest_est_date, file_count: contents.length, directory_list: debug_info}
      else
        return nil
      end
    end

    def utc_to_est_date(date)
      date.in_time_zone("America/New_York")
    end

    def process_ftp_contents(ftp, contents, timezone)
      dates = []

      contents.each do |content|
        dates << fake_utc_to_utc(ftp.mtime(content), timezone)
      end

      sort_utc_dates(dates)
    end

    def fake_utc_to_utc(date, timezone)
      # Yes, seconds and nanoseconds will never be needed, but it is how the default Time object returns the time.
      # Defaults are good (And makes sure tests pass because...Time).
      ActiveSupport::TimeZone[timezone].parse(date.strftime("%Y-%m-%d %H:%M:%S.%N")).utc
    end

    def is_backed_up?(date, minutes_to_check)
      date < minutes_to_check.minutes.ago.utc
    end

    def sort_utc_dates(dates)
      dates.sort { |a, b| a <=> b }
    end

    def ftp_chdir(ftp, directory)
      ftp.chdir(directory)
    end

    def ftp_connection(hostname)
      ftp = ftp_client(hostname)
      ftp.passive = true
      ftp
    end

    def ftp_client(hostname)
      Net::FTP.new(hostname)
    end

    def ftp_login(ftp, username, password)
      ftp.login(username, password)
    end
  end
end
