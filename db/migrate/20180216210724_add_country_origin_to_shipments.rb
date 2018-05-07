class AddCountryOriginToShipments < ActiveRecord::Migration
  def change
    add_column :shipments, :country_origin_id, :integer
  end
end
