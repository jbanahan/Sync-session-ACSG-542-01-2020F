class AddPayableTypeCheckNumberToIntacctPayables < ActiveRecord::Migration
  def change
    add_column :intacct_payables, :payable_type, :string
    add_column :intacct_payables, :check_number, :string
  end
end
