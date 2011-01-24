class CreateSearchCriterions < ActiveRecord::Migration
  def self.up
    create_table :search_criterions do |t|
      t.string :module_type
      t.string :field_name
      t.string :condition
      t.string :value
      t.integer :milestone_plan_id

      t.timestamps
    end
  end

  def self.down
    drop_table :search_criterions
  end
end
