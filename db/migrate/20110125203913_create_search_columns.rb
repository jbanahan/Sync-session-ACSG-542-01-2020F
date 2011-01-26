class CreateSearchColumns < ActiveRecord::Migration
  def self.up
    create_table :search_columns do |t|
      t.integer :search_setup_id
      t.integer :rank
      t.string :model_field_uid
      t.integer :custom_definition_id

      t.timestamps
    end
  end

  def self.down
    drop_table :search_columns
  end
end
