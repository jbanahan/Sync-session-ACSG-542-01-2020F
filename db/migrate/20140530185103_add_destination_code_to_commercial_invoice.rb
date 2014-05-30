class AddDestinationCodeToCommercialInvoice < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :destination_code, :string
  end
end
