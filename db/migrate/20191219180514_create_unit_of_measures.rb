class CreateUnitOfMeasures < ActiveRecord::Migration
  def change
    create_table :unit_of_measures do |t|
      t.string :uom
      t.string :description
      t.string :system

      t.timestamps null: false
    end
    add_index :unit_of_measures, [:uom, :system]
  end
end
