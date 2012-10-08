class AddImporterToProduct < ActiveRecord::Migration
  def self.up
    add_column :products, :importer_id, :integer
    add_index :products, :importer_id
  end

  def self.down
    remove_index :products, :importer_id
    remove_column :products, :importer_id
  end
end
