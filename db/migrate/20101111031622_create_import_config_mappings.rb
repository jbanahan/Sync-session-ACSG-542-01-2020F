class CreateImportConfigMappings < ActiveRecord::Migration
  def self.up
    create_table :import_config_mappings do |t|
      t.string :model_field_uid
      t.integer :column

      t.timestamps
    end
  end

  def self.down
    drop_table :import_config_mappings
  end
end
