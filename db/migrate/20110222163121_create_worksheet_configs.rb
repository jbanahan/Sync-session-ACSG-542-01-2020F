class CreateWorksheetConfigs < ActiveRecord::Migration
  def self.up
    create_table :worksheet_configs do |t|
      t.string :name
      t.string :module_type

      t.timestamps
    end
  end

  def self.down
    drop_table :worksheet_configs
  end
end
