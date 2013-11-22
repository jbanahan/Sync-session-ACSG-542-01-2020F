class AddK84MonthToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :k84_month, :int
  end
end
