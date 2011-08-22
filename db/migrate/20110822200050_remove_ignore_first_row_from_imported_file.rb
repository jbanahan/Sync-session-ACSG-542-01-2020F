class RemoveIgnoreFirstRowFromImportedFile < ActiveRecord::Migration
  def self.up
    remove_column :imported_files, :ignore_first_row
  end

  def self.down
    add_column :imported_files, :ignore_first_row, :boolean
  end
end
