class AddPaperclipFieldsToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :attached_file_name, :string
    add_column :imported_files, :attached_content_type, :string
    add_column :imported_files, :attached_file_size, :integer
    add_column :imported_files, :attached_updated_at, :datetime
  end

  def self.down
    remove_column :imported_files, :attached_updated_at
    remove_column :imported_files, :attached_file_size
    remove_column :imported_files, :attached_content_type
    remove_column :imported_files, :attached_file_name
  end
end
