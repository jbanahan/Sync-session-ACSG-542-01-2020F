class ChangeIntacctPayableLinesAmountPrecision < ActiveRecord::Migration
  def up
    change_column :intacct_payable_lines, :amount, :decimal, :precision => 12, :scale => 2
  end

  def down
    change_column :intacct_payable_lines, :amount, :decimal, :precision => 10, :scale => 2
  end
end
