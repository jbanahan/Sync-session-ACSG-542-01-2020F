class AddVesselNationalityToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :vessel_nationality, :string
  end
end
