require 'net/ftp'

class FtpSender
#THIS CLASS IS NOT UNIT TESTED.  THOUGHTS ON BEST WAY TO UNIT TEST ARE WELCOME!

  #send a file via FTP
  #opts = :binary (defaults to true) 
  #  :folder (defaults to nil)
  #  :remote_file_name (defaults to local file name)
  #  :passive (defaults to true)
  def self.send_file server, username, password, file, opts = {}
    log = ["Attempting to send FTP file to #{server} with username #{username}."]
    begin
      my_opts = {:binary=>true,:passive=>true,:remote_file_name=>File.basename(file),
        :force_empty=>false}.merge opts
      remote_name = my_opts[:remote_file_name]
      write_file_to_db = false
      if File.new(file).size > 0 || my_opts[:force_empty]
        write_file_to_db = true
        Net::FTP.open(server) do |f|
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
          if my_opts[:binary]
            data = File.open(file, "rb") {|f| f.read}
            f.putbinaryfile file, remote_name
            log << "Put binary file #{file.to_s} as #{remote_name}"
          else
            f.puttextfile file, remote_name
            log << "Put text file #{file.to_s} as #{remote_name}"
            data = File.open(file, "r") {|f| f.read}
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
      FtpSession.create!(:username => username,
                        :server => server,
                        :file_name => File.basename(file),
                        :log => log.join("\n"),
                        :data => (write_file_to_db ? File.open(file, "rb") { |f| f.read } : nil))
    end
  end

  #no idea why this is here
  def abc

  end
end
