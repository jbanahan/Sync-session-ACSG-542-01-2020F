class AddSiToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :shipment_instructions_sent_date, :date
    add_column :shipments, :shipment_instructions_sent_by_id, :integer
  end
end
