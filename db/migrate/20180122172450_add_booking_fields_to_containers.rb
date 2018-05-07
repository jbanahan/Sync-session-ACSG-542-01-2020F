class AddBookingFieldsToContainers < ActiveRecord::Migration
  def up
    change_table :containers, bulk:true do |t|
      t.date :container_pickup_date
      t.date :container_return_date
      t.integer :port_of_loading_id
      t.integer :port_of_delivery_id
    end
  end

  def down
    remove_column :containers, :container_pickup_date
    remove_column :containers, :container_return_date
    remove_column :containers, :port_of_loading_id
    remove_column :containers, :port_of_delivery_id
  end
end
