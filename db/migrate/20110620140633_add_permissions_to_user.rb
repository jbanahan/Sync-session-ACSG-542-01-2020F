class AddPermissionsToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :order_view, :boolean
    add_column :users, :order_edit, :boolean
    add_column :users, :order_delete, :boolean
    add_column :users, :order_comment, :boolean
    add_column :users, :order_attach, :boolean

    add_column :users, :shipment_view, :boolean
    add_column :users, :shipment_edit, :boolean
    add_column :users, :shipment_delete, :boolean
    add_column :users, :shipment_comment, :boolean
    add_column :users, :shipment_attach, :boolean

    add_column :users, :sales_order_view, :boolean
    add_column :users, :sales_order_edit, :boolean
    add_column :users, :sales_order_delete, :boolean
    add_column :users, :sales_order_comment, :boolean
    add_column :users, :sales_order_attach, :boolean

    add_column :users, :delivery_view, :boolean
    add_column :users, :delivery_edit, :boolean
    add_column :users, :delivery_delete, :boolean
    add_column :users, :delivery_comment, :boolean
    add_column :users, :delivery_attach, :boolean

    add_column :users, :product_view, :boolean
    add_column :users, :product_edit, :boolean
    add_column :users, :product_delete, :boolean
    add_column :users, :product_comment, :boolean
    add_column :users, :product_attach, :boolean

    add_column :users, :classification_view, :boolean
    add_column :users, :classification_edit, :boolean
  end

  def self.down
    remove_column :users, :order_view
    remove_column :users, :order_edit
    remove_column :users, :order_delete
    remove_column :users, :order_comment
    remove_column :users, :order_attach

    remove_column :users, :shipment_view
    remove_column :users, :shipment_edit
    remove_column :users, :shipment_delete
    remove_column :users, :shipment_comment
    remove_column :users, :shipment_attach

    remove_column :users, :sales_order_view
    remove_column :users, :sales_order_edit
    remove_column :users, :sales_order_delete
    remove_column :users, :sales_order_comment
    remove_column :users, :sales_order_attach

    remove_column :users, :delivery_view
    remove_column :users, :delivery_edit
    remove_column :users, :delivery_delete
    remove_column :users, :delivery_comment
    remove_column :users, :delivery_attach

    remove_column :users, :product_view
    remove_column :users, :product_edit
    remove_column :users, :product_delete
    remove_column :users, :product_comment
    remove_column :users, :product_attach

    remove_column :users, :classification_view
    remove_column :users, :classification_edit
  end
end
