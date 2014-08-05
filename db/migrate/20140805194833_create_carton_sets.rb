class CreateCartonSets < ActiveRecord::Migration
  def change
    create_table :carton_sets do |t|
      t.integer :starting_carton
      t.integer :carton_qty
      t.decimal :length_cm, :precision => 8, :scale=>4
      t.decimal :width_cm, :precision => 8, :scale=>4
      t.decimal :height_cm, :precision => 8, :scale=>4
      t.decimal :net_net_kgs, :precision => 8, :scale=>4
      t.decimal :net_kgs, :precision => 8, :scale=>4
      t.decimal :gross_kgs, :precision => 8, :scale=>4
      t.integer :shipment_id

      t.timestamps
    end
    add_index :carton_sets, :shipment_id
  end
end
