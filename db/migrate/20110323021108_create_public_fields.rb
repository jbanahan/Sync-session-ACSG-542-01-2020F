class CreatePublicFields < ActiveRecord::Migration
  def self.up
    create_table :public_fields do |t|
      t.string :model_field_uid
      t.boolean :searchable

      t.timestamps
    end
  end

  def self.down
    drop_table :public_fields
  end
end
