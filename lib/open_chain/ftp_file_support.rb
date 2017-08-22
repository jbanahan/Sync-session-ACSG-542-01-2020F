module OpenChain
  module FtpFileSupport

    # ftp the given file to the appropriate location for this product generator
    # will return true if subclass responds to ftp_credentials and file is sent without error
    # will return false if file is nil or doesn't exist
    # option_overrides will override values from ftp_credentials
    def ftp_file file, option_overrides = {}
      send_status = false

      if !file.nil? && File.exists?(file.to_path)
        begin
          opts = ftp_information(option_overrides)
          delete_local = !opts[:keep_local]
          session = FtpSender.send_file(opts[:server],opts[:username],opts[:password],file,opts)
          if block_given?
            yield session
          end

          # The reason we also return true from this is because of how we transparently handle file
          # resends should the initial send fail.  Ergo, just because the send fails on the first attempt, 
          # doesn't mean the file needs to be regenerated, so we always return true if the call to 
          # FtpSender.send_file completes.  The retry handling built into FtpSender will notify
          # if the file truly can't be sent.
          send_status = true
        ensure
          if delete_local
            if !file.closed?
              file.is_a?(Tempfile) ? file.close! : file.close
            end

            File.unlink(file.path) unless file.is_a?(Tempfile)
          end
        end
      end
      send_status
    end

    def ftp_sync_file file, sync_records, option_overrides = {}
      ftp_file(file, option_overrides) do |session|
        Array.wrap(sync_records).each {|sr| sr.ftp_session = session }
      end
    end

    def ftp2_vandegrift_inc folder, remote_file_name = nil
      opts = {server: 'ftp2.vandegriftinc.com', username: 'VFITRACK', password: 'RL2VFftp', folder: folder}
      opts[:remote_file_name] = remote_file_name unless remote_file_name.blank?
      opts
    end

    def connect_vfitrack_net folder, remote_file_name = nil
      opts = {server: 'connect.vfitrack.net', username: 'www-vfitrack-net', password: 'phU^`kN:@T27w.$', folder: folder, protocol: 'sftp', port: 2222}
      opts[:remote_file_name] = remote_file_name unless remote_file_name.blank?
      opts
    end

    def ecs_connect_vfitrack_net folder, remote_file_name = nil
      opts = {server: 'connect.vfitrack.net', username: 'ecs', password: 'wzuomlo', folder: folder, protocol: 'sftp', port: 2222}
      opts[:remote_file_name] = remote_file_name unless remote_file_name.blank?
      opts
    end

    def fenixapp_vfitrack_net folder, remote_file_name = nil
      opts = {server: 'fenixapp.vfitrack.net', username: 'vfitrack', password: 'bJzgt1S##t', folder: folder, protocol: 'sftp'}
      opts[:remote_file_name] = remote_file_name unless remote_file_name.blank?
      opts
    end

    def ftp_information ftp_file_options
      option_data = self.respond_to?(:ftp_credentials) ? ftp_credentials : {}

      # Prefer the data given in the options to that in the ftp_credentials method (if it even exists)
      option_data.merge ftp_file_options
    end
  end
end