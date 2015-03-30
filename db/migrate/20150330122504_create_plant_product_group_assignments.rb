class CreatePlantProductGroupAssignments < ActiveRecord::Migration
  def change
    create_table :plant_product_group_assignments do |t|
      t.integer :plant_id
      t.integer :product_group_id

      t.timestamps
    end
    add_index :plant_product_group_assignments, :plant_id
    add_index :plant_product_group_assignments, :product_group_id
  end
end
