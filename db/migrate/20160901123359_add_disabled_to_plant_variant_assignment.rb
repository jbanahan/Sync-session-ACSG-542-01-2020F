class AddDisabledToPlantVariantAssignment < ActiveRecord::Migration
  def change
    add_column :plant_variant_assignments, :disabled, :boolean
    add_index :plant_variant_assignments, [:plant_id,:disabled]
    add_index :plant_variant_assignments, [:variant_id,:disabled]
    add_index :plant_variant_assignments, [:disabled]
  end
end
