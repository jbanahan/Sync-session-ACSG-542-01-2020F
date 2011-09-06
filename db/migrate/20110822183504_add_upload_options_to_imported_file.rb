class AddUploadOptionsToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :update_mode, :string
    add_column :imported_files, :starting_row, :integer, :default => 1
    add_column :imported_files, :starting_column, :integer, :default => 1
  end

  def self.down
    remove_column :imported_files, :starting_column
    remove_column :imported_files, :starting_row
    remove_column :imported_files, :update_mode
  end
end
