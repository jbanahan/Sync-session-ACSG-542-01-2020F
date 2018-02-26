class AddHouseBillsOfLadingToCommercialInvoices < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :house_bills_of_lading, :text
  end
end
