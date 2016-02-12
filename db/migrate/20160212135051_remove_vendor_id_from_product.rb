class RemoveVendorIdFromProduct < ActiveRecord::Migration
  def up
    remove_column :products, :vendor_id
  end

  def down
    add_column :products, :vendor_id, :integer
  end
end
