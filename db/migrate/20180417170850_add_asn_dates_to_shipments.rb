class AddAsnDatesToShipments < ActiveRecord::Migration
  def up
    change_table :shipments, bulk: true do |t|
      t.datetime :empty_out_at_origin_date
      t.datetime :empty_return_date
      t.datetime :container_unloaded_date
      t.datetime :carrier_released_date
      t.datetime :customs_released_carrier_date
      t.datetime :available_for_delivery_date
      t.datetime :full_ingate_date
      t.datetime :full_out_gate_discharge_date
      t.datetime :on_rail_destination_date
      t.datetime :full_container_discharge_date
      t.datetime :arrive_at_transship_port_date
      t.datetime :barge_depart_date
      t.datetime :barge_arrive_date
      t.datetime :fcr_created_final_date
      t.datetime :bol_date
    end
  end

  def down
    remove_column :shipments, :empty_out_at_origin_date
    remove_column :shipments, :empty_return_date
    remove_column :shipments, :shp_container_unloaded_date
    remove_column :shipments, :shp_carrier_released_date
    remove_column :shipments, :shp_customs_released_carrier_date
    remove_column :shipments, :shp_available_for_delivery_date
    remove_column :shipments, :shp_full_ingate_date
    remove_column :shipments, :shp_full_out_gate_discharge_date
    remove_column :shipments, :shp_on_rail_destination_date
    remove_column :shipments, :shp_full_container_discharge_date
    remove_column :shipments, :shp_arrive_at_transship_port_date
    remove_column :shipments, :shp_barge_depart_date
    remove_column :shipments, :shp_barge_arrive_date
    remove_column :shipments, :shp_fcr_created_final_date
    remove_column :shipments, :shp_bol_date
  end
end
