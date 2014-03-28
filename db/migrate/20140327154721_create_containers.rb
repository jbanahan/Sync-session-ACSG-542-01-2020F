class CreateContainers < ActiveRecord::Migration
  def change
    create_table :containers do |t|
      t.string :container_number
      t.string :container_size
      t.string :size_description
      t.integer :weight
      t.integer :quantity
      t.string :uom
      t.string :goods_description
      t.string :seal_number
      t.integer :teus
      t.string :fcl_lcl
      t.references :entry

      t.timestamps
    end
    add_index :containers, :entry_id
  end
end
