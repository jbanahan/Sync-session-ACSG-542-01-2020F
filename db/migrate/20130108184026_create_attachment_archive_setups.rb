class CreateAttachmentArchiveSetups < ActiveRecord::Migration
  def change
    create_table :attachment_archive_setups do |t|
      t.integer :company_id
      t.date :start_date

      t.timestamps
    end
    add_index :attachment_archive_setups, :company_id
  end
end
