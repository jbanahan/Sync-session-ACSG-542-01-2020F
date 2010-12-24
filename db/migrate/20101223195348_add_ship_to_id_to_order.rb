class AddShipToIdToOrder < ActiveRecord::Migration
  def self.up
    add_column :orders, :ship_to_id, :integer
  end

  def self.down
    remove_column :orders, :ship_to_id
  end
end
