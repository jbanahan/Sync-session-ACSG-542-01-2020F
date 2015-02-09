class AddCargoReadyDateToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :cargo_ready_date, :date
  end
end
