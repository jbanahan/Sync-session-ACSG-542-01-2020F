class AddAllianceFieldsToCommercialInvoice < ActiveRecord::Migration
  def self.up
    add_column :commercial_invoices, :currency, :string
    add_column :commercial_invoices, :exchange_rate, :decimal, :precision=>8, :scale=>6
    add_column :commercial_invoices, :invoice_value_foreign, :decimal, :precision=>13, :scale=>2
    add_column :commercial_invoices, :invoice_value, :decimal, :precision=>13, :scale=>2
    add_column :commercial_invoices, :country_origin_code, :string
    add_column :commercial_invoices, :gross_weight, :integer
    add_column :commercial_invoices, :total_charges, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoices, :invoice_date, :date
    add_column :commercial_invoices, :mfid, :string
  end

  def self.down
    remove_column :commercial_invoices, :mfid
    remove_column :commercial_invoices, :invoice_date
    remove_column :commercial_invoices, :total_charges
    remove_column :commercial_invoices, :gross_weight
    remove_column :commercial_invoices, :country_origin_code
    remove_column :commercial_invoices, :invoice_value
    remove_column :commercial_invoices, :invoice_value_foreign
    remove_column :commercial_invoices, :exchange_rate
    remove_column :commercial_invoices, :currency
  end
end
