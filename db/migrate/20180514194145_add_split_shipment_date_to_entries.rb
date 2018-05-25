class AddSplitShipmentDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :split_shipment_date, :datetime
  end
end
