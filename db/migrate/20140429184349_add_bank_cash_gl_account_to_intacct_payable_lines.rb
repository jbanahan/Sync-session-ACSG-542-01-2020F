class AddBankCashGlAccountToIntacctPayableLines < ActiveRecord::Migration
  def change
    add_column :intacct_payable_lines, :bank_cash_gl_account, :string
  end
end
