class AddCustomerReferenceToIntacctReceivables < ActiveRecord::Migration
  def change
    add_column :intacct_receivables, :customer_reference, :string
  end
end
