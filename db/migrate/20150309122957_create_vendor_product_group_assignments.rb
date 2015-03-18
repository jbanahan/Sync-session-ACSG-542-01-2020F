class CreateVendorProductGroupAssignments < ActiveRecord::Migration
  def change
    create_table :vendor_product_group_assignments do |t|
      t.integer :vendor_id
      t.integer :product_group_id

      t.timestamps
    end
    add_index :vendor_product_group_assignments, :vendor_id
    add_index :vendor_product_group_assignments, :product_group_id
  end
end
