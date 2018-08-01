class AddManuallyGeneratedToInvoices < ActiveRecord::Migration
  def change
    add_column :invoices, :manually_generated, :boolean
  end
end
