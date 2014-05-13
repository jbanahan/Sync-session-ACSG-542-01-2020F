module OpenChain
  module FtpFileSupport

    # ftp the given file to the appropriate location for this product generator
    # will return true if subclass responds to ftp_credentials and file is sent without error
    # will return false if file is nil or doesn't exist
    # option_overrides will override values from ftp_credentials
    def ftp_file file, option_overrides = {}
      send_status = false

      if self.respond_to?(:ftp_credentials) && !file.nil? && File.exists?(file.path)
        begin
          opts = {}
          c = ftp_credentials.merge(option_overrides)
          delete_local = !c[:keep_local]
          opts[:folder] = c[:folder] unless c[:folder].blank?
          opts[:remote_file_name] = c[:remote_file_name] unless c[:remote_file_name].blank?
          FtpSender.send_file(c[:server],c[:username],c[:password],file,opts)
          send_status = true
        ensure
          file.unlink if delete_local
        end
      end
      send_status
    end


    def ftp2_vandegrift_inc folder, remote_file_name = nil
      opts = {server: 'ftp2.vandegriftinc.com', username: 'VFITRACK', password: 'RL2VFftp', folder: folder}
      opts[:remote_file_name] = remote_file_name unless remote_file_name.blank?
      opts
    end
  end
end