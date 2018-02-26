class AddMasterBillsOfLadingToCommercialInvoices < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :master_bills_of_lading, :text
  end
end
