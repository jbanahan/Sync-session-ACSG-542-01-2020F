class AddVoidedToIntacctChecks < ActiveRecord::Migration
  def change
    add_column :intacct_checks, :voided, :boolean

    execute "UPDATE intacct_checks SET voided = 0 WHERE amount >= 0"
    execute "UPDATE intacct_checks SET voided = 1 WHERE amount < 0"
  end
end
