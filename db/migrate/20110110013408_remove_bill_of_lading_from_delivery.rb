class RemoveBillOfLadingFromDelivery < ActiveRecord::Migration
  def self.up
    remove_column :deliveries, :bill_of_lading
  end

  def self.down
    add_column :deliveries, :bill_of_lading, :string
  end
end
