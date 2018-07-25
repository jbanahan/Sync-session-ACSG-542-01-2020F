class AddAgricultureLicenseNumberToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :agriculture_license_number, :string
  end
end
