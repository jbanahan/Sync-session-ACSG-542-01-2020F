class AddCanceledOrderLineIdToShipmentLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :canceled_order_line_id, :integer
  end
end
