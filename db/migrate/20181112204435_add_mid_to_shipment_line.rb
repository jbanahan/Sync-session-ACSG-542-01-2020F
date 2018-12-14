class AddMidToShipmentLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :mid, :string
  end
end
