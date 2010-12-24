class AddImportConfigIdToImportConfigMapping < ActiveRecord::Migration
  def self.up
    add_column :import_config_mappings, :import_config_id, :integer
  end

  def self.down
    remove_column :import_config_mappings, :import_config_id
  end
end
