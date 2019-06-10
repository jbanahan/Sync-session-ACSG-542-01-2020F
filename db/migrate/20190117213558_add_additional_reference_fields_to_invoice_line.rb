class AddAdditionalReferenceFieldsToInvoiceLine < ActiveRecord::Migration
  def up
    change_table(:invoice_lines, bulk: true) do |t|
      t.string :carrier_name
      t.string :customer_reference_number
      t.string :customer_reference_number_2
      t.string :secondary_po_number
      t.string :secondary_po_line_number
      t.string :house_bill_of_lading
      t.string :sku
    end
  end

  def down
    change_table(:invoice_lines, bulk: true) do |t|
      t.remove :carrier_name
      t.remove :customer_reference_number
      t.remove :customer_reference_number_2
      t.remove :secondary_po_number
      t.remove :secondary_po_line_number
      t.remove :house_bill_of_lading
      t.remove :sku
    end
  end
end
