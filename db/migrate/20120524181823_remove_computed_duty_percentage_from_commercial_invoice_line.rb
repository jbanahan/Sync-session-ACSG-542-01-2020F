class RemoveComputedDutyPercentageFromCommercialInvoiceLine < ActiveRecord::Migration
  def self.up
    remove_column :commercial_invoice_lines, :computed_duty_percentage
    add_column :commercial_invoice_tariffs, :duty_rate, :decimal, :precision=>4, :scale=>3
  end

  def self.down
    remove_column :commercial_invoice_tariffs, :duty_rate
    add_column :commercial_invoice_lines, :computed_duty_percentage, :decimal, :precision=>8, :scale=>2
  end
end
