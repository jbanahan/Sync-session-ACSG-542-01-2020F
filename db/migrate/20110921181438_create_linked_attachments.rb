class CreateLinkedAttachments < ActiveRecord::Migration
  def self.up
    create_table :linked_attachments do |t|
      t.integer :linkable_attachment_id
      t.string :attachable_type
      t.integer :attachable_id

      t.timestamps
    end
    add_index :linked_attachments, [:attachable_id,:attachable_type], {:name=>'linked_type'}
    add_index :linked_attachments, :linkable_attachment_id, {:name=>'linked_attch_id'}
  end

  def self.down
    drop_table :linked_attachments
  end
end
