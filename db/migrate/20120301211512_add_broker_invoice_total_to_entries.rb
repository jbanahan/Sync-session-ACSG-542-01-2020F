class AddBrokerInvoiceTotalToEntries < ActiveRecord::Migration
  def self.up
    add_column :entries, :broker_invoice_total, :decimal, :precision => 12, :scale => 2
  end

  def self.down
    remove_column :entries, :broker_invoice_total
  end
end
