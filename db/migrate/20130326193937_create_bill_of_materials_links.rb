class CreateBillOfMaterialsLinks < ActiveRecord::Migration
  def change
    create_table :bill_of_materials_links do |t|
      t.integer :parent_product_id
      t.integer :child_product_id
      t.integer :quantity
    end
    add_index :bill_of_materials_links, :parent_product_id
    add_index :bill_of_materials_links, :child_product_id
  end
end
