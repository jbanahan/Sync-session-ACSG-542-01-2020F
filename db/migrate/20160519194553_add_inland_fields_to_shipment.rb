class AddInlandFieldsToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :inland_destination_port_id, :integer
    add_column :shipments, :est_inland_port_date, :date
    add_column :shipments, :inland_port_date, :date

    add_index :shipments, :inland_destination_port_id
  end
end
