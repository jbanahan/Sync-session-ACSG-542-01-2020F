class AddBillOfLadingToShipments < ActiveRecord::Migration
  def self.up
    add_column :shipments, :bill_of_lading, :string
  end

  def self.down
    remove_column :shipments, :bill_of_lading
  end
end
