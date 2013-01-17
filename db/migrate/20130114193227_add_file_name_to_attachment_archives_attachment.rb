class AddFileNameToAttachmentArchivesAttachment < ActiveRecord::Migration
  def change
    add_column :attachment_archives_attachments, :file_name, :string
  end
end
