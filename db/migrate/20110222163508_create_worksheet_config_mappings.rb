class CreateWorksheetConfigMappings < ActiveRecord::Migration
  def self.up
    create_table :worksheet_config_mappings do |t|
      t.integer :row
      t.integer :column
      t.string :model_field_uid
      t.integer :custom_definition_id
      t.integer :worksheet_config_id

      t.timestamps
    end
  end

  def self.down
    drop_table :worksheet_config_mappings
  end
end
