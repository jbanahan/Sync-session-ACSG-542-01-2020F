class AddCurrencyToBrokerInvoice < ActiveRecord::Migration
  def self.up
    add_column :broker_invoices, :currency, :string
    execute "UPDATE broker_invoices SET currency = \"USD\";"
  end

  def self.down
    remove_column :broker_invoices, :currency
  end
end
