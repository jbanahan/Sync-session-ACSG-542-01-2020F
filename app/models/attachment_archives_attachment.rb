class AttachmentArchivesAttachment < ActiveRecord::Base
  attr_accessible :attachment_archive_id, :attachment_id, :file_name

  belongs_to :attachment, :inverse_of=>:attachment_archives_attachments
  belongs_to :attachment_archive, :inverse_of=>:attachment_archives_attachments
end
