require 'net/ftp'

class FtpSender
#THIS CLASS IS NOT UNIT TESTED.  THOUGHTS ON BEST WAY TO UNIT TEST ARE WELCOME!

  #send a file via FTP
  #opts = :binary (defaults to false) 
  #  :folder (defaults to nil)
  #  :remote_file_name (defaults to local file name)
  def self.send_file server, username, password, file, opts = {}
    my_opts = {:binary=>false}.merge opts
    remote_name = my_opts[:remote_file_name].nil? ? File.basename(file) : my_opts[:remote_file_name]
    Net::FTP.open(server) do |f|
      f.login(username,password)
      f.chdir(my_opts[:folder]) if my_opts[:folder]
      if my_opts[:binary]
        f.putbinaryfile file, remote_name
      else
        f.puttextfile file, remote_name
      end
    end
  end

  def abc

  end
end
