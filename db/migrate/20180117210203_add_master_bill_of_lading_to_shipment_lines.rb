class AddMasterBillOfLadingToShipmentLines < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :master_bill_of_lading, :string
  end
end
