require 'open_chain/s3'
require 'open_chain/ftp_file_support'

module OpenChain; module SendFileToTest
  extend OpenChain::FtpFileSupport

  def self.execute bucket, path, options: {}
    OpenChain::S3.download_to_tempfile(bucket, path, options) do |temp|
      folder = "#{MasterSetup.get.send_test_files_to_instance}/#{Pathname.new(path).parent.basename}"
      ftp_file temp, ecs_connect_vfitrack_net(folder, Pathname.new(path).basename.to_s)
    end
  end

end; end
