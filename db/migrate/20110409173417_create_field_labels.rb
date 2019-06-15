class CreateFieldLabels < ActiveRecord::Migration
  def self.up
    create_table :field_labels do |t|
      t.string :model_field_uid
      t.string :label

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :field_labels
  end
end
