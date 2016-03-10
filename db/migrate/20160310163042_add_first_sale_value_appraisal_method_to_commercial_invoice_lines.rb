class AddFirstSaleValueAppraisalMethodToCommercialInvoiceLines < ActiveRecord::Migration
  def up
    change_table(:commercial_invoice_lines, bulk: true) do |t|
      t.boolean :first_sale
      t.string :value_appraisal_method
    end
  end

  def down
    change_table(:commercial_invoice_lines, bulk: true) do |t|
      t.remove :first_sale, :value_appraisal_method
    end
  end
end
