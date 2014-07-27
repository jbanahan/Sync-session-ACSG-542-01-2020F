class AddShipWindowToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :ship_window_start, :date
    add_column :orders, :ship_window_end, :date
    add_column :orders, :first_expected_delivery_date, :date
    add_index :orders, :ship_window_start
    add_index :orders, :ship_window_end
    add_index :orders, :first_expected_delivery_date
  end
end
