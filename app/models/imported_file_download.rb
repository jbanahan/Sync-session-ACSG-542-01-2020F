class ImportedFileDownload < ActiveRecord::Base
  belongs_to :imported_file, :inverse_of=>:imported_file_downloads
  belongs_to :user, :inverse_of=>:imported_file_downloads

  has_attached_file :attached, :path => ":master_setup_uuid/imported_file_download/:id/:filename"
  # Paperclip, as of v4, forces you to list all the attachment types you allow to be uploaded.  We don't restrict these
  # at all, so this disables that validation.
  do_not_validate_attachment_file_type :attached
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
