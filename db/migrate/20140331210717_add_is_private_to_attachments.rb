class AddIsPrivateToAttachments < ActiveRecord::Migration
  def change
    add_column :attachments, :is_private, :boolean
  end
end
