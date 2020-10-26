require 'net/ftp'
require 'net/sftp'

class FtpSender
# THIS CLASS IS NOT UNIT TESTED.  THOUGHTS ON BEST WAY TO UNIT TEST ARE WELCOME!

  # send a file via FTP
  # arg_file - can be a path to a file or an actual File object
  # opts = :binary (defaults to true)
  #  :folder (defaults to nil)
  #  :remote_file_name (defaults to local file name)
  #  :passive (defaults to true)
  #  :force_empty (default = false) - send zero length files
  #  :protocol - if set to "sftp" sftp will be used, anything else will use plain ftp
  #  :attachment_id - if set to an int value, the file associated with the id will be sent (in this value is set, the file argument can be nil)
  #  :skip_virus_scan - skip_virus_scan, if set to true (and true only), will bypass the virus scan done on all attachments.  This should only EVER
  #   be used in situations where the file may be huge and scanning it cause issues AND when you know the file is ok (.ie composed of attachments that
  #   have already been scanned).
  def self.send_file server, username, password, arg_file, opts = {}
    raise ArgumentError, "Server and username are required." unless server.present? && username.present?
    # This needs to be outside the get_file_to_ftp otherwise we end up with a potentially wrong default remote file name
    # when the options come from a JSON option string (.ie retries)
    opts = opts.with_indifferent_access
    get_file_to_ftp(arg_file, opts) do |file|

      my_opts = default_options(arg_file, file).merge(opts).with_indifferent_access
      log = ["Attempting to #{my_opts[:protocol]} file to #{server} with username #{username}#{my_opts[:port].to_i > 0 ? " using port #{my_opts[:port]}" : ""}."]
      remote_name = my_opts[:remote_file_name]
      store_sent_file = false
      ftp_client = nil
      # Attempt to send 10 times total
      max_retry_count = 9
      error = nil
      empty_file = false
      begin
        # Use pathname here instead of just stat'ing the file because there are instances where the file handle
        # may not have been used directly to write the data, but there is in fact data to be read from the filesystem.
        # In this case file.size returns 0, when, in fact, the file on the actual filesystem (which we use below in send_file) does have data.
        pathname = Pathname.new(file.path)
        if (pathname.exist? && pathname.size > 0) || my_opts[:force_empty]
          store_sent_file = true
          # Handles connecting and logging in
          ftp_client = get_ftp_client my_opts
          ftp_client.connect(server, username, password, log, my_opts) do |f|
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
          empty_file = true
          log << FtpSession::EMPTY_MESSAGE
        end
      rescue => e
        # Just throw an error into the log, the retry/excepton logging occurs in the ensure block
        log << "ERROR: #{e.message}"
        error = e
      ensure
        session = find_ftp_session remote_name, (store_sent_file ? file : nil), my_opts
        session.assign_attributes(:username => username,
                          :server => server,
                          :file_name => remote_name,
                          :log => log.join("\n"),
                          :last_server_response => (ftp_client.nil? ? nil : ftp_client.last_response),
                          :protocol => my_opts[:protocol],
                          :retry_count => session.retry_count ? session.retry_count + 1 : 0)

        # We don't really want to save off empty ftp file send sessions, there's no real point.
        # We do, however, want to return a session always from the send..so, just return one that hasn't
        # been created yet
        return session if empty_file

        session.save!

        # No attachment means that there was a blank file attempted to be sent
        # If the error object is not nill, we ALWAYS want to retry...this can happen in a case where the last command was
        # technically successful (like changing dirs), but then the file send timed out.
        unless session.attachment.nil? || (error.nil? && session.successful?) || !MasterSetup.ftp_enabled?
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
            error.log_me ["Attempted and failed to send #{my_opts[:protocol]} Session id #{session.id} #{max_retry_count + 1} times. No more attempts will be made."]
          end

        end
        return session
      end
    end
  end

  def self.default_options arg_file, local_file
    # arg_file is the originally file that was passed into the send method
    # local file is the file object that's actually being used to send the data
    # use arg_file because that's the only thing that may have an original_filename method associated with it
    # since we generally won't have gotten that same object to send (for a variety of reasons - see get_file_to_ftp)
    filename = arg_file.respond_to?(:original_filename) ? arg_file.original_filename : File.basename(local_file)

    {:binary=>true, :passive=>true, :remote_file_name=>filename,
            :force_empty=>false, :protocol=>"ftp"}.with_indifferent_access
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
        Attachment.add_original_filename_method file, remote_name
        att = session.build_attachment
        att.skip_virus_scan = true if opts[:skip_virus_scan] == true
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
      # If the arg_file is a string or pathname, we'll turn it into a File object so that paperclip (session.attachment) can handle it
      # Only automatically close file objects that we've created in this method
      local_file_creation = arg_file.is_a?(String) || arg_file.is_a?(Pathname)
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
    if MasterSetup.ftp_enabled?
      my_opts[:protocol] == "sftp" ? SftpClient.new : FtpClient.new
    else
      NoOpFtpClient.new
    end
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

  class FtpFile
    attr_reader :name, :size, :mtime

    def initialize name, size, mtime, file_type
      @name = name
      @size = size
      @mtime = mtime
      @file_type = file_type
    end

    def file?
      @file_type == "file"
    end

    def directory?
      @file_type == "directory"
    end
  end

  class FtpClient
    attr_accessor :log

    def connect server, user, password, log, opts, &block
      @client = Net::FTP.new
      port = opts[:port] || '21'
      @log = log
      begin
        @client.connect(server, port)
        @client.login(user, password)
        block.call self
      rescue => e
        handle_exception e
      ensure
        @client.close rescue err
      end
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

    # Returns an array FtpFile objects representing all the files in the
    # current working directory.
    #
    # Files will by default be converted to the time in the current Time.zone
    # use a different convert_to_time_zone value to change to something else
    #
    # By default only actual files are returned, to list directories too
    # pass false the include_only_files param
    def list_files convert_to_time_zone: Time.zone, include_only_files: true
      @client.mlsd.map do |f|
        next if include_only_files && !f.file?

        # I'm sure there's other types of entries other than just file and directory but I'm just going to assume
        # anything that's not a file is a directory
        FtpSender::FtpFile.new(f.pathname, f.size, f.modify.in_time_zone(convert_to_time_zone),  (f.file? ? "file" : "directory"))
      end.compact
    end

    # Simple pass-thru method to the underlying client's version of this method.
    def get_binary_file remote_file, local_file = File.basename(remote_file), block_size = Net::FTP::DEFAULT_BLOCKSIZE, &block
      @client.getbinaryfile remote_file, local_file, block_size, &block
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

    def connect server, user, password, log, opts, &block
      # In net-ssh 5, verify_host_key should be changed to :never

      # Other remote servers don't appear to always support compression, so we're going to use compression just with connect.vfitrack.net or ftp2.vandegriftinc.com
      compression = ["connect.vfitrack.net", "ftp2.vandegriftinc.com"].include?(server)

      sftp_opts = {password: password, compression: compression, verify_host_key: false, timeout: 10, auth_methods: ["password"]}
      if opts[:port]
        sftp_opts[:port] = opts[:port]
      end

      # verify_host_key = :never - Disables host key verfication (if this is enabled, errors are thrown here if the remote host changes its host key)
      # This would happen any time we spun up new server instances internally since the IP's change.
      @session_completed = false
      Net::SFTP.start(server, user, sftp_opts) do |client|
        @client = client
        @log = log
        @remote_path = Pathname.new ''
        set_ok_response
        block.call self
        @session_completed = true
      end
      nil
    rescue => e
      handle_exception e
      nil
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

    # Returns an array FtpFile objects representing all the files in the
    # current working directory.
    #
    # Files will by default be converted to the time in the current Time.zone
    # use a different convert_to_time_zone value to change to something else
    #
    # By default only actual files are returned, to list directories too
    # pass false the include_only_files param
    def list_files convert_to_time_zone: Time.zone, include_only_files: true
      @client.dir.entries(@remote_path.to_s).map do |f|
        next if include_only_files && !f.file?

        # I'm sure there's other types of entries other than just file and directory but I'm just going to assume
        # anything that's not a file is a directory
        FtpSender::FtpFile.new(f.name, f.attributes.size, Time.at(f.attributes.mtime).in_time_zone(convert_to_time_zone), (f.file? ? "file" : "directory"))
      end.compact

    end

    # Simple pass-thru method to the underlying client's version of this method.
    def get_binary_file remote_file, local_file = File.basename(remote_file), block_size = Net::FTP::DEFAULT_BLOCKSIZE, &block
      @client.getbinaryfile remote_file, local_file, block_size, &block
    end

    private
      def session_completed?
        @session_completed == true
      end

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
          # If this is a status exception, we'll also need to strip out the Net::SFTP::Response object from it
          # since it contains a whole bunch of stuff that can't be serialized to a delayed job queue (procs, primarily)
          e.instance_variable_set("@response", nil)
        else
          # There's a bug in Wing FTP server or the ssh/sftp gem code that results in a Disconnect exception being
          # thrown when session.close is called inside the sftp#start method (this all works fine for standard sshd).
          # This shouldn't happen, and it's not an actual error situation (hence not propigating it).  So for now,
          # just swallow the error if the session completed, until we know Wing FTP has resolved the issue.
          if e.is_a?(Net::SSH::Disconnect) && session_completed?
            return nil
          else
            # Just indicate something bad happened - generic error code for sftp is 4
            @last_response = "4 #{e.message}"
          end
        end
        raise e
      end
  end

  class NoOpFtpClient

    attr_accessor :log, :remote_path

    def connect server, user, password, log, opts
      log << "File sending has been disabled for this environment.  All log messages after this are for reference only...no files were sent."
      set_ok_response
      @remote_path = Pathname.new ''
      yield self
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
      set_ok_response
    end

    def last_response
      @last_response
    end

    def append_path path, append
      Pathname.new(path + append).cleanpath
    end

    def set_ok_response
      @last_response = "200 OK"
    end
  end
end
