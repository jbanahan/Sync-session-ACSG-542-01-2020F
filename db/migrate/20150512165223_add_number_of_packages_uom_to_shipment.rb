class AddNumberOfPackagesUomToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :number_of_packages_uom, :string
  end
end
