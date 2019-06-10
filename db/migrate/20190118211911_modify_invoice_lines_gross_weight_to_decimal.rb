class ModifyInvoiceLinesGrossWeightToDecimal < ActiveRecord::Migration
  def up
    change_column :invoice_lines, :gross_weight, :decimal, precision: 12, scale: 2
  end

  def down
    change_column :invoice_lines, :gross_weight, :integer
  end
end
