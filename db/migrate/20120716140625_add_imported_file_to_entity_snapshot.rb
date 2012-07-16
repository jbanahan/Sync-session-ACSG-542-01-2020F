class AddImportedFileToEntitySnapshot < ActiveRecord::Migration
  def self.up
    add_column :entity_snapshots, :imported_file_id, :integer
    add_index :entity_snapshots, :imported_file_id
  end

  def self.down
    remove_index :entity_snapshots, :imported_file_id
    remove_column :entity_snapshots, :imported_file_id
  end
end
