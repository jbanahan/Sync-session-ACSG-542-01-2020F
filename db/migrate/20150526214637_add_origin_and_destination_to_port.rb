class AddOriginAndDestinationToPort < ActiveRecord::Migration
  def change
    add_column :ports, :active_origin, :boolean
    add_column :ports, :active_destination, :boolean
  end
end
