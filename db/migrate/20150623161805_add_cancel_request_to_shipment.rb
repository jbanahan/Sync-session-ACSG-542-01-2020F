class AddCancelRequestToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :cancel_requested_at, :datetime
    add_column :shipments, :cancel_requested_by_id, :integer
  end
end
