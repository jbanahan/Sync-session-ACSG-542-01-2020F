class RemoveVendorIdFromProduct < ActiveRecord::Migration
  def up
    execute "INSERT INTO product_vendor_assignments (product_id, vendor_id, created_at, updated_at) SELECT id, vendor_id, now(), now() FROM products WHERE vendor_id is not null"
    remove_column :products, :vendor_id
  end

  def down
    add_column :products, :vendor_id, :integer
  end
end
