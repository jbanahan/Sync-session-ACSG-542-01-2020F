class ChangeShippingAddressFlags < ActiveRecord::Migration
  def self.up
		remove_column :addresses, :ship_from
		remove_column :addresses, :ship_to
		add_column :addresses, :shipping, :boolean
  end

  def self.down
		remove_column :addresses, :shipping
		add_column		:addresses,	:ship_to, :boolean
		add_column		:addresses, :ship_from, :boolean
  end
end
