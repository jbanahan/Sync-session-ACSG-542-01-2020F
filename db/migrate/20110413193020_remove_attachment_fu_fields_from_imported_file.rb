class RemoveAttachmentFuFieldsFromImportedFile < ActiveRecord::Migration
  def self.up
    remove_column :imported_files, :filename
    remove_column :imported_files, :size
    remove_column :imported_files, :content_type
  end

  def self.down
    add_column :imported_files, :filename, :string
    add_column :imported_files, :size, :string
    add_column :imported_fiels, :content_type, :string
  end
end
