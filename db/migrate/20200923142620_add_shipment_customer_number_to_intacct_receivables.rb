class AddShipmentCustomerNumberToIntacctReceivables < ActiveRecord::Migration
  def change
    add_column :intacct_receivables, :shipment_customer_number, :string
  end
end
