class CreateEmailAttachments < ActiveRecord::Migration
  def self.up
    create_table :email_attachments do |t|
      t.string :email, :limit => 1024
      t.integer :attachment_id

      t.timestamps
    end
  end

  def self.down
    drop_table :email_attachments
  end
end
