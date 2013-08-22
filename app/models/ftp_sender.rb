require 'net/ftp'

class FtpSender
#THIS CLASS IS NOT UNIT TESTED.  THOUGHTS ON BEST WAY TO UNIT TEST ARE WELCOME!

  #send a file via FTP
  #opts = :binary (defaults to true) 
  #  :folder (defaults to nil)
  #  :remote_file_name (defaults to local file name)
  #  :passive (defaults to true)
  #  :force_empty (default = false) - send zero length files
  def self.send_file server, username, password, arg_file, opts = {}
    log = ["Attempting to send FTP file to #{server} with username #{username}."]
    ftp_client = nil

    # If the arg_file is a string, we'll turn it into a File object so that paperclip (session.attachment) can handle it
    # Only automatically close file objects that we've created in this method
    local_file_creation = arg_file.is_a? String
    file = local_file_creation ? File.open(arg_file, "rb") : arg_file
    
    my_opts = {:binary=>true,:passive=>true,:remote_file_name=>File.basename(file),
      :force_empty=>false}.merge opts
    remote_name = my_opts[:remote_file_name]
    store_sent_file = false

    begin  
      if file.size > 0 || my_opts[:force_empty]
        store_sent_file = true
        Net::FTP.open(server) do |f|
          ftp_client = f
          log << "Opened connection to #{server}"
          f.login(username,password)
          log << "Logged in with account #{username}"
          f.passive = my_opts[:passive]
          log << "Set passive to #{my_opts[:passive]}"
          if my_opts[:folder]
            f.chdir(my_opts[:folder]) 
            log << "Changed to folder #{my_opts[:folder]}" 
          end
          data = nil

          # We need to use the file path since the ftp send always closes
          # the file handle it is passed, and we need to keep that handle open 
          # so the ftp session attachment will get saved off.
          if my_opts[:binary]
            f.putbinaryfile file.path, remote_name
            log << "Put binary file #{file.path} as #{remote_name}"
          else
            f.puttextfile file.path, remote_name
            log << "Put text file #{file.path} as #{remote_name}"
          end
          log << "Session completed successfully."
        end
      else
        log << "File was empty, not sending."
      end
    rescue
      log << "ERROR: #{$!.message}"
      $!.log_me
    ensure
      session = nil
      begin
        session = FtpSession.new(:username => username,
                          :server => server,
                          :file_name => remote_name,
                          :log => log.join("\n"),
                          :last_server_response => (ftp_client ? ftp_client.last_response : nil))
        if store_sent_file && file
          # Make sure we're storing the attachment off under the name we sent it as
          Attachment.add_original_filename_method file
          file.original_filename = remote_name

          att = session.create_attachment
          att.attached = file
        end

        session.save!
      ensure
        # Always close the file, this is expected since a straight ftp send from the standard ruby libs does the same thing.
        file.close unless file.closed?
      end

      return session
    end
  end

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
end
