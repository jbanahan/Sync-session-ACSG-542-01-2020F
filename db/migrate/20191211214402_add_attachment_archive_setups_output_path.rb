class AddAttachmentArchiveSetupsOutputPath < ActiveRecord::Migration
  def change
    add_column :attachment_archive_setups, :output_path, :text
  end
end
