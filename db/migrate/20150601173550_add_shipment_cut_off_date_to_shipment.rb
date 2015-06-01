class AddShipmentCutOffDateToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :shipment_cut_off_date, :date
  end
end
