class AddDeliveryIdToHistory < ActiveRecord::Migration
  def self.up
    add_column :histories, :delivery_id, :integer
  end

  def self.down
    remove_column :histories, :delivery_id
  end
end
