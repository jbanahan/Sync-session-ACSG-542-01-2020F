class AddIncludeOnlyListedAttachmentsAndSendInRealTimeToAttachmentArchiveSetups < ActiveRecord::Migration
  def change
    add_column :attachment_archive_setups, :include_only_listed_attachments, :boolean
    add_column :attachment_archive_setups, :send_in_real_time, :boolean
  end
end
