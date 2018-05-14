class AddDiscountFieldsToCommercialInvoiceLines < ActiveRecord::Migration
  def self.up
    change_table :commercial_invoice_lines, bulk: true do |t|
      t.decimal :freight_amount, :precision => 12, :scale => 2
      t.decimal :other_amount, :precision => 12, :scale => 2
      t.decimal :cash_discount, :precision => 12, :scale => 2
      t.decimal :add_to_make_amount, :precision => 12, :scale => 2
    end
  end

  def self.down
    change_table :commercial_invoice_lines, bulk: true do |t|
      t.remove :freight_amount
      t.remove :other_amount
      t.remove :cash_discount
      t.remove :add_to_make_amount
    end
  end
end
