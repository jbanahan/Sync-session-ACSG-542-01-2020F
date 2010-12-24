class AddModeToShipments < ActiveRecord::Migration
  def self.up
    add_column :shipments, :mode, :string
  end

  def self.down
    remove_column :shipments, :mode
  end
end
