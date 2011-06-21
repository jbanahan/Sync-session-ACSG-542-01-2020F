class SetExistingPermissions < ActiveRecord::Migration
  def self.up
    execute "UPDATE users SET order_view = 1, order_edit = 1, order_delete = 1, order_comment = 1, order_attach = 1, shipment_view = 1, shipment_edit = 1, shipment_delete = 1, shipment_comment = 1, shipment_attach = 1, sales_order_view = 1, sales_order_edit = 1, sales_order_delete = 1, sales_order_comment = 1, sales_order_attach = 1, delivery_view = 1, delivery_edit = 1, delivery_delete = 1, delivery_comment = 1, delivery_attach = 1, product_view = 1, product_edit = 1, product_delete = 1, product_comment = 1, product_attach = 1, classification_edit = 1;"
  end

  def self.down
  end
end
