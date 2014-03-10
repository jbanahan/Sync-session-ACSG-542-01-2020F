class AddStitcherOptionsToArchiveSetups < ActiveRecord::Migration
  def up
    change_table(:attachment_archive_setups) do |t|
      t.column :combine_attachments, :boolean
      t.column :combined_attachment_order, :text
    end
  end

  def down
    change_table(:attachment_archive_setups) do |t|
      t.remove :combine_attachments
      t.remove :combined_attachment_order
    end
  end
end
