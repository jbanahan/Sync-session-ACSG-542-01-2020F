class AddShipmentCustomerNumberToIntacctPayables < ActiveRecord::Migration
  def change
    add_column :intacct_payables, :shipment_customer_number, :string
  end
end
