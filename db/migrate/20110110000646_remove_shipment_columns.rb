class RemoveShipmentColumns < ActiveRecord::Migration
  def self.up
    remove_column :shipments, :eta
    remove_column :shipments, :etd
    remove_column :shipments, :ata
    remove_column :shipments, :atd
    remove_column :shipments, :bill_of_lading
  end

  def self.down
    add_column :shipments, :eta, :date
    add_column :shipments, :etd, :date
    add_column :shipments, :ata, :date
    add_column :shipments, :atd, :date
    add_column :shipments, :bill_of_lading, :string
  end
end
