require 'open_chain/send_file_to_test'

module IntegrationParserSupport
  extend ActiveSupport::Concern

  # get the S3 path for the last file used to update this entry (if one exists)
  def last_file_secure_url(expires_in = 60.seconds)
    return nil unless has_last_file?
    OpenChain::S3.url_for(self.last_file_bucket, self.last_file_path, expires_in)
  end

  # This method is basically only here so that the view helper can determine if there is a last file
  # without having to generate a url (which involves an HTTP request to S3 so we don't do it unless we have to)
  def has_last_file? # rubocop:disable Naming/PredicateName
    self.class.has_last_file? self.last_file_bucket, self.last_file_path
  end

  def can_view_integration_link? user
    return false unless self.has_last_file?
    return true if user.sys_admin?
    user.admin? && MasterSetup.get.custom_feature?('Admins View Integration Files')
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def has_last_file? bucket, path # rubocop:disable Naming/PredicateName
      bucket.present? && path.present?
    end

    def send_integration_file_to_test bucket, path
      if has_last_file?(bucket, path)
        OpenChain::SendFileToTest.delay.execute(bucket, path)
      end
    end
  end

end
