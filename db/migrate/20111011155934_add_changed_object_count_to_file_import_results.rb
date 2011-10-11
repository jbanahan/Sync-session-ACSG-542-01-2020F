class AddChangedObjectCountToFileImportResults < ActiveRecord::Migration
  def self.up
    add_column :file_import_results, :changed_object_count, :integer
  end

  def self.down
    remove_column :file_import_results, :changed_object_count
  end
end
