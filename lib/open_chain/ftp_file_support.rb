module OpenChain
  module FtpFileSupport

    # ftp the given file to the appropriate location for this product generator
    # will return true if subclass responds to ftp_credentials and file is sent without error
    # will return false if file is nil or doesn't exist
    def ftp_file file, delete_local=true
      return false unless self.respond_to? :ftp_credentials
      return false if file.nil? || !File.exists?(file.path)
      begin
        opts = {}
        c = ftp_credentials
        opts[:folder] = c[:folder] unless c[:folder].blank?
        opts[:remote_file_name] = c[:remote_file_name] unless c[:remote_file_name].blank?
        FtpSender.send_file(c[:server],c[:username],c[:password],file,opts)
      ensure
        file.unlink if delete_local
      end
      true
    end

  end
end