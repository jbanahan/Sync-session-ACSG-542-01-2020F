class AddDownloadFieldsToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :final_dest_port_id, :integer
    add_column :shipments, :confirmed_on_board_origin_date, :date
    add_column :shipments, :eta_last_foreign_port_date, :date
    add_column :shipments, :departure_last_foreign_port_date, :date
  end
end
