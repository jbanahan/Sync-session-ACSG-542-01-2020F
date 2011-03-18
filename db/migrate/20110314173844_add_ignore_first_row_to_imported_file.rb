class AddIgnoreFirstRowToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :ignore_first_row, :boolean
  end

  def self.down
    remove_column :imported_files, :ignore_first_row
  end
end
