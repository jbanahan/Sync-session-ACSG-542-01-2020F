class AddPickupDatesToEntry < ActiveRecord::Migration
  def change
    add_column :entries, :delivery_order_pickup_date, :datetime
    add_column :entries, :freight_pickup_date, :datetime
  end
end
