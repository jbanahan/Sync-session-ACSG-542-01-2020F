require 'net/ftp'
require 'net/sftp'

class FtpSender
#THIS CLASS IS NOT UNIT TESTED.  THOUGHTS ON BEST WAY TO UNIT TEST ARE WELCOME!

  #send a file via FTP
  # arg_file - can be a path to a file or an actual File object
  #opts = :binary (defaults to true) 
  #  :folder (defaults to nil)
  #  :remote_file_name (defaults to local file name)
  #  :passive (defaults to true)
  #  :force_empty (default = false) - send zero length files
  #  :protocol - if set to "sftp" sftp will be used, anything else will use plain ftp
  #  :attachment_id - if set to an int value, the file associated with the id will be sent (in this value is set, the file argument can be nil)
  def self.send_file server, username, password, arg_file, opts = {}
    # This needs to be outside the get_file_to_ftp otherwise we end up with a potentially wrong default remote file name
    # when the options come from a JSON option string (.ie retries)
    opts = opts.with_indifferent_access
    get_file_to_ftp(arg_file, opts) do |file|
      log = ["Attempting to send FTP file to #{server} with username #{username}."]
      
      my_opts = default_options(file).merge(opts).with_indifferent_access
      remote_name = my_opts[:remote_file_name]
      store_sent_file = false
      ftp_client = nil
      # Attempt to send 10 times total
      max_retry_count = 9
      begin  
        if file.size > 0 || my_opts[:force_empty]
          store_sent_file = true
          # Handles connecting and logging in
          ftp_client = get_ftp_client my_opts
          ftp_client.connect(server, username, password, log) do |f|
            log << "Opened connection to #{server}"
            log << "Logged in with account #{username}"

            f.after_login my_opts
            
            if my_opts[:folder]
              f.chdir(my_opts[:folder]) 
              log << "Changed to folder #{my_opts[:folder]}" 
            end
            data = nil

            log << "Sending file #{File.basename(file.path)} as #{remote_name}"
            # We need to use the file path since the ftp send always closes
            # the file handle it is passed, and we need to keep that handle open 
            # so the ftp session attachment will get saved off.
            f.send_file file.path, remote_name, my_opts
            log << "Session completed successfully."
          end
        else
          log << "File was empty, not sending."
        end
      rescue => e
        log << "ERROR: #{e.message}"
        e.log_me ["This exception email is only a warning. This #{my_opts[:protocol]} send attempt will be automatically retried."]
      ensure
        session = find_ftp_session remote_name, (store_sent_file ? file : nil), my_opts
        session.assign_attributes(:username => username,
                          :server => server,
                          :file_name => remote_name,
                          :log => log.join("\n"),
                          :last_server_response => (ftp_client.nil? ? nil : ftp_client.last_response),
                          :protocol => my_opts[:protocol],
                          :retry_count => session.retry_count ? session.retry_count + 1 : 0)
        session.save!

        # No attachment means that there was a blank file attempted to be sent
        unless session.attachment.nil? || session.successful?
          if session.retry_count < max_retry_count
            # Add the session id and attachment id to the options hash so the resend knows which file to send and which session to update
            my_opts[:session_id] = session.id
            my_opts[:attachment_id] = session.attachment.id
            # Make sure we're setting the remote file name so that it's the same name as the session object, otherwise we'll be sending 
            # the files using the tempfile name used when the attachment is downloaded
            my_opts[:remote_file_name] = session.file_name
            self.delay(run_at: calculate_retry_run_at(session.retry_count)).resend_file server, username, password, my_opts.to_json
          else
            # At this point, we've failed to send the file 10 times...just bail, sending an error email out to notify of the failure
            OpenMailer.send_generic_exception(StandardError.new("Attempted and failed to send FTP Session id #{session.id} #{max_retry_count} times. No more attempts will be made."), [], [], []).deliver!
          end
          
        end
        return session
      end
    end
  end

  def self.default_options file
    {:binary=>true,:passive=>true,:remote_file_name=>File.basename(file),
            :force_empty=>false, :protocol=>"ftp"}
  end

  # The starting point for the delayed job re-send attempt.
  def self.resend_file server, username, password, json_options
    options = ActiveSupport::JSON.decode(json_options)

    send_file server, username, password, nil, options  
  end

  def self.calculate_retry_run_at retry_count
    retry_count = 0 unless retry_count
    # This algorithm is cribbed from delayed job's exponential backoff retry algorithm
    # Essentially, we retry 5/6 times in semi-rapid succession and then end up retrying 2, 4, 9, and 16 hours later.
    Time.zone.now + ((retry_count + 1) ** 5) + 5
  end
  private_class_method :calculate_retry_run_at

  def self.find_ftp_session remote_name, file, opts
    session = nil
    if opts[:session_id]
      session = FtpSession.where(id: opts[:session_id]).first
    end

    unless session
      session = FtpSession.new

      if file
        # Make sure we're storing the attachment off under the name we sent it as
        Attachment.add_original_filename_method file
        file.original_filename = remote_name

        att = session.create_attachment
        att.attached = file
      end
    end

    session
  end
  private_class_method :find_ftp_session

  def self.get_file_to_ftp arg_file, opts
    # First, see if we're sending an Attachment object
    if opts[:attachment_id]
      # Fail hard if attachment isn't found
      a = Attachment.find opts[:attachment_id]
      a.download_to_tempfile do |t|
        return yield t
      end
    else
      # If the arg_file is a string, we'll turn it into a File object so that paperclip (session.attachment) can handle it
      # Only automatically close file objects that we've created in this method
      local_file_creation = arg_file.is_a? String
      file = local_file_creation ? File.open(arg_file, "rb") : arg_file
      begin
        return yield file
      ensure
        # Always close the file, this is expected since a straight ftp send from the standard ruby libs does the same thing.
        file.close unless file.closed?
      end
    end
  end
  private_class_method :get_file_to_ftp

  def self.get_ftp_client my_opts
    my_opts[:protocol] == "sftp" ? SftpClient.new : FtpClient.new
  end
  private_class_method :get_ftp_client

  # Another send method where the info parameter is expected to be an FtpInformation object
  # so that all "standard" ftp information can be encapsulated into a single object
  def self.upload info, file, alternate_file_name = nil, opts = {}
    new_opts = opts.clone
    new_opts[:folder] = info.remote_directory if info.remote_directory
    new_opts[:remote_file_name] = alternate_file_name if alternate_file_name

    send_file info.server, info.user, info.password, file, new_opts
  end

  class FtpInformation
    attr_accessor :server, :user, :password, :remote_directory

    def initialize server, user, password, remote_directory = nil
      @server = server
      @user = user
      @password = password
      @remote_directory = remote_directory
    end
  end

  class FtpClient
    attr_accessor :log

    def connect server, user, password, log, &block
      Net::FTP.open(server, user, password) do |client|
        @client = client
        @log = log
        block.call self
      end
    rescue => e
      handle_exception e
    end

    def after_login opts={}
      @client.passive = opts[:passive]
      @log << "Set passive to #{opts[:passive]}"
    end

    def chdir folder, opts={}
      @client.chdir(folder) 
    end

    def send_file local_path, remote_name, opts={}
      if opts[:binary]
        @log << "Sending binary file."
        @client.putbinaryfile local_path, remote_name
      else
        @log << "Sending text file."
        @client.puttextfile local_path, remote_name
      end
    end

    def last_response 
      @client ? @client.last_response : (@last_response ? @last_response : "")
    end

    private 
      def handle_exception e
        if e.is_a? Net::FTPError
          # Status exceptions have an actual error code associated with them and the description which we can 
          # use to set the last response value (like with ftp codes)
          @last_response = "#{e.message}"
        else
          # Just indicate something bad happened - generic error code for FTP Errors is 500 series
          @last_response = "500 #{e.message}"
        end
        raise e
      end
  end

  class SftpClient
    attr_accessor :log, :remote_path

    def connect server, user, password, log, &block
      # paranoid = false - Disables host key verfication (if this is enabled, errors are thrown here if the remote host changes its host key)
      # This would happen any time we spun up new server instances internally since the IP's change.
      Net::SFTP.start(server, user, password: password, compression: true, paranoid: false) do |client|
        @client = client
        @log = log
        @remote_path = Pathname.new ''
        set_ok_response
        block.call self
      end

    rescue => e
      handle_exception e
    end

    def after_login opts={}
      # at this point, this is a no-op
    end

    def chdir folder, opts={}
      # SFTP servers have no actual concept of current directories so we end up having
      # to emulate it by keeping a remote path variable for the session (see connect method)

      # cleanpath handles any folder traversals that might be done from the folder variable .ie 'path/blagh/../new'.cleanpath = 'path/new' 
      @remote_path = append_path @remote_path, folder
    end

    def send_file local_path, remote_name, opts={}
      # synthesize the remote filename from the path
      remote_path = append_path @remote_path, remote_name
      
      @client.upload! local_path, remote_path.to_s
      set_ok_response
    rescue => e
      handle_exception e
    end

    def last_response 
      @last_response
    end

    private 
      def append_path path, append
        Pathname.new(path + append).cleanpath
      end

      def set_ok_response
        @last_response = "0 OK"
      end

      def handle_exception e
        if e.is_a? Net::SFTP::StatusException
          # Status exceptions have an actual error code associated with them and the description which we can 
          # use to set the last response value (like with ftp codes)
          @last_response = "#{e.code} #{e.description}"
        else
          # Just indicate something bad happened - generic error code for sftp is 4
          @last_response = "4 #{e.message}"
        end
        raise e
      end
  end
end
