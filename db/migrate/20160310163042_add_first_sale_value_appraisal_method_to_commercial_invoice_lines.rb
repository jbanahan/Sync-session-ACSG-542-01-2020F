class AddFirstSaleValueAppraisalMethodToCommercialInvoiceLines < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_lines, :first_sale, :boolean
    add_column :commercial_invoice_lines, :value_appraisal_method, :string
  end
end
