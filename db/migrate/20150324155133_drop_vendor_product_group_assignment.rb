class DropVendorProductGroupAssignment < ActiveRecord::Migration
  def up
    drop_table :vendor_product_group_assignments
  end

  def down
    #no rollback on this one, good luck
  end
end
