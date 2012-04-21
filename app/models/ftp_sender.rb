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
    Net::FTP.open(server) do |f|
      f.login(username,password)
      f.passive = my_opts[:passive]
      f.chdir(my_opts[:folder]) if my_opts[:folder]
      data = nil
      if my_opts[:binary]
        data = File.open(file, "rb") {|f| f.read}
        f.putbinaryfile file, remote_name
      else
        f.puttextfile file, remote_name
        data = File.open(file, "r") {|f| f.read}
      end
      FtpSession.create!(:username => username,
                          :server => server,
                          :file_name => File.basename(file),
                          :log => "Uploading file",
                          :data => File.open(file, "rb") { |f| f.read })
    end
  end

  def abc

  end
end
