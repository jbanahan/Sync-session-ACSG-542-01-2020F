class AddImporterIdToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :importer_id, :integer
    add_index :entries, :importer_id
  end

  def self.down
    remove_index :entries, :importer_id
    remove_column :entries, :importer_id
  end
end
