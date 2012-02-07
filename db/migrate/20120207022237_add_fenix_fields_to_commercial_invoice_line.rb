class AddFenixFieldsToCommercialInvoiceLine < ActiveRecord::Migration
  def self.up
    add_column :commercial_invoice_lines, :state_export_code, :string
    add_column :commercial_invoice_lines, :state_origin_code, :string
    add_column :commercial_invoice_lines, :unit_price, :decimal, :precision=>12, :scale=>3
  end

  def self.down
    remove_column :commercial_invoice_lines, :unit_price
    remove_column :commercial_invoice_lines, :state_origin_code
    remove_column :commercial_invoice_lines, :state_export_code
  end
end
