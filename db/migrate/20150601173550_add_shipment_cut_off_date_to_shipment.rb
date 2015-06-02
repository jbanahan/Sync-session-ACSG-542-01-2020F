class AddShipmentCutOffDateToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :shipment_cutoff_date, :date
  end
end
