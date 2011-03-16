class KillImportConfigs < ActiveRecord::Migration
  def self.up
    drop_table :import_config_mappings
    drop_table :import_configs
  end

  def self.down
    create_table :import_configs do |t|
      t.string :name
      t.string :model_type
      t.boolean :ignore_first_row
      t.string :file_type
      t.timestamps
    end
    create_table :import_config_mappings do |t|
      t.string :model_field_uid
      t.integer :column_rank
      t.integer :import_config_id
      t.integer :custom_definition_id
    end
  end
end
