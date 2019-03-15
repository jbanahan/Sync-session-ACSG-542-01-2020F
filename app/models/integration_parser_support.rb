require 'open_chain/ftp_file_support'

module IntegrationParserSupport
  include OpenChain::FtpFileSupport
  extend ActiveSupport::Concern

  #get the S3 path for the last file used to update this entry (if one exists)
  def last_file_secure_url(expires_in=60.seconds)
    return nil unless has_last_file?
    AWS::S3.new(AWS_CREDENTIALS).buckets[self.last_file_bucket].objects[self.last_file_path].url_for(:read,:expires=>expires_in,:secure=>true).to_s
  end

  # This method is basically only here so that the view helper can determine if there is a last file
  # without having to generate a url (which involves an HTTP request to S3 so we don't do it unless we have to)
  def has_last_file?
    self.class.has_last_file? self.last_file_bucket, self.last_file_path
  end

  def can_view_integration_link? user
    return false unless self.has_last_file?
    return true if user.sys_admin?
    return user.admin? && MasterSetup.get.custom_feature?('Admins View Integration Files')
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def has_last_file? bucket, path
      !bucket.blank? && !path.blank?
    end

    def send_integration_file_to_test bucket, path
      if has_last_file? bucket, path
        OpenChain::S3.download_to_tempfile(bucket, path) do |temp|
          folder = "#{MasterSetup.get.send_test_files_to_instance}/#{Pathname.new(path).parent.basename.to_s}"
          support_instance = self.new
          support_instance.ftp_file temp, support_instance.ecs_connect_vfitrack_net(folder, Pathname.new(path).basename.to_s)
        end
      end
    end
  end

end
