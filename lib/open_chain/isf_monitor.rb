require 'net/ftp'

module OpenChain
  class IsfMonitor
    def self.run_schedulable opts = {}
      hostname = opts['hostname']
      username = opts['username']
      password = opts['password']
      directory = opts['directory']
      minutes_to_check = opts['duration'].to_i

      raise "hostname, username, password and directory must be passed in" if hostname.blank? || username.blank? || password.blank? || directory.blank?

      self.new.run(hostname, username, password, directory, minutes_to_check)
    end

    def run(hostname, username, password, directory, minutes_to_check)
      ftp = ftp_connection(hostname)
      ftp_login(ftp, username, password)
      ftp_chdir(ftp, directory)
      contents = ftp.nlst

      return unless contents.present?

      file_dates = process_ftp_contents(ftp, contents)
      oldest_est_date = utc_to_est_date(file_dates[0])

      if is_backed_up?(file_dates[0], minutes_to_check)
        to = ['isf@vandegriftinc.com', 'mzeitlin@vandegriftinc.com', 'agriffin@vandegriftinc.com', 'bglick@vandegriftinc.com', 'support@vandegriftinc.com']
        subject = "ISF PROCESSING STUCK"
        body = "Kewill EDI ISF processing is suck. The oldest file in the folder is from #{oldest_est_date} and there are #{contents.length} files in the folder<br />Please call Brian Glick - 215-821-6595 to escalate."
        OpenMailer::send_simple_html(to, subject, body).deliver
      end
    end

    def utc_to_est_date(date)
      date.in_time_zone("America/New_York")
    end

    def process_ftp_contents(ftp, contents)
      dates = []

      contents.each do |content|
        dates << ftp.mtime(content)
      end

      sort_utc_dates(dates)
    end

    def is_backed_up?(date, minutes_to_check)
      Time.zone.now.utc < date || date < minutes_to_check.minutes.ago.utc
    end

    def sort_utc_dates(dates)
      dates.sort { |a, b| a <=> b }
    end

    def ftp_chdir(ftp, directory)
      ftp.chdir(directory)
    end

    def ftp_connection(hostname)
      ftp = Net::FTP.new(hostname)
      ftp.passive = true
      ftp
    end

    def ftp_login(ftp, username, password)
      ftp.login(username, password)
    end
  end
end
