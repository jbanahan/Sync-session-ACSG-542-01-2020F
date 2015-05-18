class AddNumberOfPackagesToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :number_of_packages, :int
  end
end
