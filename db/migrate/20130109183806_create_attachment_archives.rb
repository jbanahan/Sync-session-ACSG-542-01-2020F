class CreateAttachmentArchives < ActiveRecord::Migration
  def change
    create_table :attachment_archives do |t|
      t.integer :company_id
      t.string :name
      t.datetime :start_at
      t.datetime :finish_at

      t.timestamps
    end
    add_index :attachment_archives, :company_id
    create_table :attachment_archives_attachments do |t|
      t.integer :attachment_archive_id
      t.integer :attachment_id
    end
    add_index :attachment_archives_attachments, :attachment_archive_id, :name=>'arch_id'
    add_index :attachment_archives_attachments, :attachment_id, :name=>'att_id'
  end
end
