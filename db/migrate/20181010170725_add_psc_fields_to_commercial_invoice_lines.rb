class AddPscFieldsToCommercialInvoiceLines < ActiveRecord::Migration
  def self.up
    change_table(:commercial_invoice_lines, bulk: true) do |t|
      t.string :psc_reason_code
      t.datetime :psc_date
    end 
  end

  def self.down
    change_table(:commercial_invoice_lines, bulk: true) do |t|
      t.remove :psc_reason_code, :psc_date
    end
  end
end

