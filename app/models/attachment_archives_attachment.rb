# == Schema Information
#
# Table name: attachment_archives_attachments
#
#  attachment_archive_id :integer
#  attachment_id         :integer
#  file_name             :string(255)
#  id                    :integer          not null, primary key
#
# Indexes
#
#  arch_id  (attachment_archive_id)
#  att_id   (attachment_id)
#

class AttachmentArchivesAttachment < ActiveRecord::Base
  attr_accessible :attachment_archive_id, :attachment_id, :file_name

  belongs_to :attachment, :inverse_of=>:attachment_archives_attachments
  belongs_to :attachment_archive, :inverse_of=>:attachment_archives_attachments

  # Defines the output path (including filename) to use when archiving this attachment.
  # The path here is the path relative to the archive root folder for this 
  # specific archive instance - ie. AttachmentArchive.name.
  # Use /'s to designate subdirectories.
  def output_path
    # We may need to do company specific checks in the future, but for now, everyone will just
    # be broker_reference/filename
    # This is also assuming we're only archiving entries.
    return "#{attachment.attachable.broker_reference}/#{self.file_name}"
  end

end
