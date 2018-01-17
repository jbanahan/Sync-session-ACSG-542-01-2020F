class AddTotalTaxesToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :total_taxes, :decimal, :precision => 12, :scale => 2
  end
end
