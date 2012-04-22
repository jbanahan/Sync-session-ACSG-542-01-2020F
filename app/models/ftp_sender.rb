require 'net/ftp'

class FtpSender
#THIS CLASS IS NOT UNIT TESTED.  THOUGHTS ON BEST WAY TO UNIT TEST ARE WELCOME!

  #send a file via FTP
  #opts = :binary (defaults to false) 
  #  :folder (defaults to nil)
  #  :remote_file_name (defaults to local file name)
  def self.send_file server, username, password, file, opts = {}
    my_opts = {:binary=>true,:passive=>true}.merge opts
    remote_name = my_opts[:remote_file_name].nil? ? File.basename(file) : my_opts[:remote_file_name]
    log = ["Attempting to send FTP file."]
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
      FtpSession.create!(:username => username,
                          :server => server,
                          :file_name => File.basename(file),
                          :log => log.join("\n"),
                          :data => File.open(file, "rb") { |f| f.read })
    end
  end

  def abc

  end
end
