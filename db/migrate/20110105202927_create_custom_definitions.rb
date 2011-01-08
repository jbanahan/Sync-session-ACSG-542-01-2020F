class CreateCustomDefinitions < ActiveRecord::Migration
  def self.up
    create_table :custom_definitions do |t|
      t.string :label
      t.string :data_type
      t.integer :rank
      t.string :module_type

      t.timestamps
    end
  end

  def self.down
    drop_table :custom_definitions
  end
end
