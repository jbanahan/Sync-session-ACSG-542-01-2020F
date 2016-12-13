class AddDataCrossReferencesIndexOnTypeValue < ActiveRecord::Migration
  def up
    add_index :data_cross_references, [:cross_reference_type, :value]
  end

  def down
    remove_index :data_cross_references, [:cross_reference_type, :value]
  end
end
