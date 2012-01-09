class AddDrawbackQtyToCommercialInvoiceLine < ActiveRecord::Migration
  def self.up
    add_column :commercial_invoice_lines, :drawback_qty, :decimal, :precision => 11, :scale => 2
  end

  def self.down
    remove_column :commercial_invoice_lines, :drawback_qty
  end
end
