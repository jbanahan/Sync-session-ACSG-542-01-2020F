class AddCommercialInvoiceIdToHistory < ActiveRecord::Migration
  def self.up
    add_column :histories, :commercial_invoice_id, :integer
  end

  def self.down
    remove_column :histories, :commercial_invoice_id
  end
end
