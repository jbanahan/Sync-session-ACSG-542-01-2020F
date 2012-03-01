class ChangeCiLineUnitsToQuantity < ActiveRecord::Migration
  def self.up
    rename_column :commercial_invoice_lines, :units, :quantity
  end

  def self.down
    rename_column :commercial_invoice_lines, :quantity, :units
  end
end
