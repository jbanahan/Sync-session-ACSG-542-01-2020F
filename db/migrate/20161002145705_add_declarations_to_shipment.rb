class AddDeclarationsToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :hazmat, :boolean
    add_column :shipments, :solid_wood_packing_materials, :boolean
    add_column :shipments, :lacey_act, :boolean
    add_column :shipments, :export_license_required, :boolean
  end
end
