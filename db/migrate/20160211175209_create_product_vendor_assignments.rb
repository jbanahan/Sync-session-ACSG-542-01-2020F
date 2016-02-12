class CreateProductVendorAssignments < ActiveRecord::Migration
  def change
    create_table :product_vendor_assignments do |t|
      t.integer :product_id
      t.integer :vendor_id

      t.timestamps
    end
    add_index :product_vendor_assignments, :product_id
    add_index :product_vendor_assignments, :vendor_id
  end
end
