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
      contents = ftp.ls
      return unless contents.present?
      sorted_dates = process_ftp_ls(contents)
      if is_backed_up?(sorted_dates[0], minutes_to_check)
        to = ['isf@vandegriftinc.com', 'mzeitlin@vandegriftinc.com', 'agriffin@vandegriftinc.com', 'bglick@vandegriftinc.com', 'support@vandegriftinc.com']
        subject = "ISF PROCESSING STUCK"
        body = "Kewill EDI ISF processing is suck. The oldest file in the folder is from #{sorted_dates[0]} and there are #{contents.length} files in the folder<br />Please call Brian Glick - 215-821-6595 to escalate."
        OpenMailer::send_simple_html(to, subject, body).deliver
      end
    end

    def is_backed_up?(date, minutes_to_check)
      Time.zone.now.utc < date || date < minutes_to_check.minutes.ago.utc
    end

    def process_ftp_ls(contents)
      dates = parse_ftp_dates(contents)
      est_dates = ftp_dates_to_est(dates)
      utc_dates = est_dates_to_utc_dates(est_dates)
      sort_utc_dates(utc_dates)
    end

    def sort_utc_dates(dates)
      dates.sort { |a, b| a <=> b }
    end

    def est_dates_to_utc_dates(dates)
      dates.map { |date| date.utc }
    end

    def ftp_dates_to_est(dates)
      dates.map { |a| Time.parse(a).in_time_zone('Eastern Time (US & Canada)') }
    end

    def parse_ftp_dates(contents)
      dates = nil
      dates = contents.map { |listing| /\d\d:\d\d/.match listing }
      dates = dates.map { |date| date[0] }

      dates
    end

    def ftp_chdir(ftp, directory)
      ftp.chdir(directory)
    end

    def ftp_connection(hostname)
      Net::FTP.new(hostname)
    end

    def ftp_login(ftp, username, password)
      ftp.login(username, password)
    end
  end
end
