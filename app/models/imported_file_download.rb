class ImportedFileDownload < ActiveRecord::Base
  belongs_to :imported_file, :inverse_of=>:imported_file_downloads
  belongs_to :user, :inverse_of=>:imported_file_downloads

  has_attached_file :attached, :path => ":master_setup_uuid/imported_file_download/:id/:filename"
  before_create :sanitize
  before_post_process :no_post

  def attachment_data
    OpenChain::S3.get_data attached.options[:bucket], attached.path
  end
  private
  def no_post
    false
  end

  def sanitize
    Attachment.sanitize_filename self, :attached
  end
end
