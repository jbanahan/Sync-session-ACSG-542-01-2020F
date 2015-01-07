class AddSubheaderNumberToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :subheader_number, :integer
  end
end
