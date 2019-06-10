class AddCountryImportSecondCustomerReferenceToInvoices < ActiveRecord::Migration
  def up
    change_table(:invoices, bulk: true) do |t|
      t.integer :country_import_id
      t.string :customer_reference_number_2
    end
  end

  def down
    change_table(:invoices, bulk: true) do |t|
      t.remove :country_import_id
      t.remove :customer_reference_number_2
    end
  end
end
