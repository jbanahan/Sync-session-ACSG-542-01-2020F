class CreateAttachments < ActiveRecord::Migration
  def self.up
    create_table :attachments do |t|
      t.references :attachable, :polymorphic => true
      t.string :attached_file_name
      t.string :attached_content_type
      t.integer :attached_file_size
      t.datetime :attached_updated_at
      t.integer :uploaded_by_id

      t.timestamps
    end
  end

  def self.down
    drop_table :attachments
  end
end
