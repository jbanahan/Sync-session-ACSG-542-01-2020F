class CreatePlantVariantAssignments < ActiveRecord::Migration
  def change
    create_table :plant_variant_assignments do |t|
      t.references :plant, null: false
      t.references :variant, null: false

      t.timestamps null: false
    end
    add_index :plant_variant_assignments, :plant_id
    add_index :plant_variant_assignments, :variant_id
  end
end
