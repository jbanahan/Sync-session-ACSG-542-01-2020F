class AddUpdatedAtIndexToAttachments < ActiveRecord::Migration
  def change
    add_index :attachments, :updated_at
  end

end
