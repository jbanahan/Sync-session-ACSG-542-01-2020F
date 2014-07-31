class AddTotalAddTotalCvdToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :total_add, :decimal, :precision => 13, :scale => 4
    add_column :entries, :total_cvd, :decimal, :precision => 13, :scale => 4
  end
end
