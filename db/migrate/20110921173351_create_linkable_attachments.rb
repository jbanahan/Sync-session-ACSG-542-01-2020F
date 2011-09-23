class CreateLinkableAttachments < ActiveRecord::Migration
  def self.up
    create_table :linkable_attachments do |t|
      t.string :model_field_uid
      t.string :value
      t.integer :attachment_id

      t.timestamps
    end
    add_index :linkable_attachments, :model_field_uid, {:name=>'linkable_mfuid'}
    add_index :linkable_attachments, :attachment_id, {:name=>'linkable_attachment_id'}
  end

  def self.down
    drop_table :linkable_attachments
  end
end
