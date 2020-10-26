class AddNetWeightToCommercialInvoices < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :net_weight, :decimal, precision: 11, scale: 2
  end
end
