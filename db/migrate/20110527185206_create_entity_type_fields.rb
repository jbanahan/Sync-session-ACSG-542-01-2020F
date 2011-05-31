class CreateEntityTypeFields < ActiveRecord::Migration
  def self.up
    create_table :entity_type_fields do |t|
      t.string :model_field_uid
      t.integer :entity_type_id

      t.timestamps
    end
    add_index :entity_type_fields, :entity_type_id
  end

  def self.down
    drop_table :entity_type_fields
  end
end
