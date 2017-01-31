class AddTotalNonDutiablAmountToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :total_non_dutiable_amount, :decimal, precision: 13, scale: 2
  end
end
