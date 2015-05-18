class AddLastForeignPortToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :last_foreign_port_id, :int
  end
end
