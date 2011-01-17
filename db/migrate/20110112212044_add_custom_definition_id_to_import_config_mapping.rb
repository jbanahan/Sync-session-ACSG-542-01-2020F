class AddCustomDefinitionIdToImportConfigMapping < ActiveRecord::Migration
  def self.up
    add_column :import_config_mappings, :custom_definition_id, :integer
  end

  def self.down
    remove_column :import_config_mappings, :custom_definition_id
  end
end
