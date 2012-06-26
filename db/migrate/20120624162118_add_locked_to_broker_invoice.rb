class AddLockedToBrokerInvoice < ActiveRecord::Migration
  def self.up
    add_column :broker_invoices, :locked, :boolean
  end

  def self.down
    remove_column :broker_invoices, :locked
  end
end
