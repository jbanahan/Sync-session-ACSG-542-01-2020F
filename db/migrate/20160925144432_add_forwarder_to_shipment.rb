class AddForwarderToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :forwarder_id, :integer
    add_index  :shipments, :forwarder_id
  end
end
