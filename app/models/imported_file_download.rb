# == Schema Information
#
# Table name: imported_file_downloads
#
#  additional_countries  :string(255)
#  attached_content_type :string(255)
#  attached_file_name    :string(255)
#  attached_file_size    :integer
#  attached_updated_at   :datetime
#  created_at            :datetime         not null
#  id                    :integer          not null, primary key
#  imported_file_id      :integer
#  updated_at            :datetime         not null
#  user_id               :integer
#
# Indexes
#
#  index_imported_file_downloads_on_imported_file_id  (imported_file_id)
#

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
