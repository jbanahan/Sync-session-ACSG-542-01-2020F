class AddTotalFreightToEntries < ActiveRecord::Migration
  def change
    change_table :entries do |t|
      t.decimal :total_freight, precision: 12, scale: 2
    end
  end
end
