class RemoveImportConfigIdFromImportedFile < ActiveRecord::Migration
  def self.up
    remove_column :imported_files, :import_config_id
  end

  def self.down
    add_column :imported_files, :import_config_id, :integer
  end
end
