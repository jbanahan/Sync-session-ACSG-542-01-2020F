class CreateSortCriterions < ActiveRecord::Migration
  def self.up
    create_table :sort_criterions do |t|
      t.integer :search_setup_id
      t.integer :rank
      t.string :model_field_uid
      t.integer :custom_definition_id
      t.boolean :descending

      t.timestamps
    end
  end

  def self.down
    drop_table :sort_criterions
  end
end
