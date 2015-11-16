class AddConsigneeToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :consignee_id, :integer
  end
end
