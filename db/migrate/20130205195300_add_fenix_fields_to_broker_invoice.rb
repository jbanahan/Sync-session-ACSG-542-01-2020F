class AddFenixFieldsToBrokerInvoice < ActiveRecord::Migration
  def change
    add_column :broker_invoices, :invoice_number, :string
    add_column :broker_invoices, :source_system, :string
    add_column :broker_invoices, :broker_reference, :string
    add_index :broker_invoices, :invoice_number
    add_index :broker_invoices, [:broker_reference,:source_system]
  end
end
