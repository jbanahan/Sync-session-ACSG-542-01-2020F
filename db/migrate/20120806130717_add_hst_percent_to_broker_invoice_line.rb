class AddHstPercentToBrokerInvoiceLine < ActiveRecord::Migration
  def self.up
    add_column :broker_invoice_lines, :hst_percent, :decimal, :precision=>4, :scale=>3
  end

  def self.down
    remove_column :broker_invoice_lines, :hst_percent
  end
end
