class AddCarrierNameToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :carrier_name, :string
  end
end
