class AddModuleTypeToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :module_type, :string
  end

  def self.down
    remove_column :imported_files, :module_type
  end
end
