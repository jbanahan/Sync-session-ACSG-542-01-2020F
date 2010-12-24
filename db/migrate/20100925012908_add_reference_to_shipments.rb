class AddReferenceToShipments < ActiveRecord::Migration
  def self.up
    add_column :shipments, :reference, :string
  end

  def self.down
    remove_column :shipments, :reference
  end
end
