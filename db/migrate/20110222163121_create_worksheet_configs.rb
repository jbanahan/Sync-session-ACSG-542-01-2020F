class CreateWorksheetConfigs < ActiveRecord::Migration
  def self.up
    create_table :worksheet_configs do |t|
      t.string :name
      t.string :module_type

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :worksheet_configs
  end
end
