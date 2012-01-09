class AddBrokerInvoiceIdToHistory < ActiveRecord::Migration
  def self.up
    add_column :histories, :broker_invoice_id, :integer
  end

  def self.down
    remove_column :histories, :broker_invoice_id
  end
end
