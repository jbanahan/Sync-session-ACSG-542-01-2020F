class AddVendorPermissionsToUser < ActiveRecord::Migration
  def change
    add_column :users, :vendor_view, :boolean
    add_column :users, :vendor_edit, :boolean
    add_column :users, :vendor_attach, :boolean
    add_column :users, :vendor_comment, :boolean
  end
end
