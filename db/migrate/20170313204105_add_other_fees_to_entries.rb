class AddOtherFeesToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :other_fees, :decimal, precision: 11, scale: 2
  end
end
