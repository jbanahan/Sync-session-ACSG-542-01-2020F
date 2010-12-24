class CreateImportConfigs < ActiveRecord::Migration
  def self.up
    create_table :import_configs do |t|
      t.string :name
      t.string :model_type
      t.boolean :ignore_first_row
      t.string :file_type

      t.timestamps
    end
  end

  def self.down
    drop_table :import_configs
  end
end
