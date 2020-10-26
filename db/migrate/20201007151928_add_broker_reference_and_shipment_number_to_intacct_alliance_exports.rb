class AddBrokerReferenceAndShipmentNumberToIntacctAllianceExports < ActiveRecord::Migration
  def change
    change_table(:intacct_alliance_exports, bulk: true) do |t|
      t.string :broker_reference
      t.string :shipment_number
      t.string :shipment_customer_number
    end
  end
end
