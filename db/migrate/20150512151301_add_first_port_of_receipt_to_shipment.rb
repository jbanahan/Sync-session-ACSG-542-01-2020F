class AddFirstPortOfReceiptToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :first_port_receipt_id, :int
  end
end
