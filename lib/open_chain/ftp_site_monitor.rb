module OpenChain; class FtpSiteMonitor
  include ActionView::Helpers::DateHelper

  def self.run_schedulable opts
    opts = opts.with_indifferent_access
    validate(opts)
    opts = build_opts(opts)

    self.new.run opts, opts[:max_age_minutes], opts[:email_to], opts[:email_subject], opts[:additional_email_message]
  end

  def self.validate opts
    raise ArgumentError, "'hostname', 'username', 'password', and 'directory' are all required." if [:protocol, :hostname, :username, :password, :directory].any? {|k| opts[k].blank? }
    raise ArgumentError, "'max_age_minutes' is required " if opts[:max_age_minutes].to_i <= 0
    raise ArgumentError, "One of 'email_to' or 'mailing_list' is required." if opts[:email_to].blank? && opts[:mailing_list].blank?
  end

  def self.build_opts opts
    if opts[:mailing_list]
      list = MailingList.where(system_code: opts[:mailing_list]).first
      raise "No Mailing List found with system code '#{opts[:mailing_list]}'." if list.nil?
      opts[:email_to] = list      
    end

    opts
  end

  def run ftp_data, max_age_minutes, email_to, email_subject, additional_email_message
    report_files_older_than = (Time.zone.now - max_age_minutes.minutes)
    files = ftp_files(ftp_data[:protocol], ftp_data[:hostname], ftp_data[:port], ftp_data[:username], ftp_data[:password], ftp_data[:directory])
    files = files.select { |f| f.mtime < report_files_older_than}

    if files.length > 0
      send_email files, ftp_data, email_to, email_subject, additional_email_message, max_age_minutes
    end
  end

  def send_email report_files, ftp_data, email_to, email_subject, additional_email_message, max_age_minutes
    body = "<p>#{report_files.length} #{"file".pluralize(report_files.length)} were found in the #{ftp_data[:directory]} directory on #{ftp_data[:hostname]} there were over #{max_age_minutes} minutes old.</p>"
    oldest_file = report_files.sort_by {|f| f.mtime }.first
    body += "<p>The oldest file is #{time_ago_in_words oldest_file.mtime} old.</p>" 
    if !additional_email_message.blank?
      body += "<p>#{additional_email_message}</p>"
    end

    email_subject = "#{ftp_data[:protocol].capitalize} monitor failure for #{ftp_data[:hostname]} / #{ftp_data[:directory]}" if email_subject.blank?

    OpenMailer::send_simple_html(email_to, email_subject, body.html_safe).deliver!
  end

  def ftp_files protocol, hostname, port, username, password, directory
    files = []
    opts = {}
    opts[:port] = port unless port.blank?

    ftp_client(protocol).connect(hostname, username, password, "", opts) do |client|
      client.chdir(directory) unless directory.blank?

      files = client.list_files
    end

    files
  end

  def analyze_files files, reporting_time
    files.select { |f| f.mtime < reporting_time }
  end

  def ftp_client protocol
    if protocol.to_s.upcase.strip == "FTP"
      return FtpSender::FtpClient.new
    else
      return FtpSender::SftpClient.new
    end
  end

end; end;