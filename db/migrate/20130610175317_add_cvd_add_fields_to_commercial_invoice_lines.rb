class AddCvdAddFieldsToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    change_table :commercial_invoice_lines do |t|
      t.string :add_case_number
      t.boolean :add_bond
      t.decimal :add_duty_amount, :add_case_value, :precision=>12, :scale=>2 
      t.decimal :add_case_percent, :precision=>5, :scale => 2

      t.string :cvd_case_number
      t.boolean :cvd_bond
      t.decimal :cvd_duty_amount, :cvd_case_value, :precision=>12, :scale=>2 
      t.decimal :cvd_case_percent, :precision=>5, :scale => 2
    end
  end
end
