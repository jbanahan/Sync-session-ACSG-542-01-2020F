class AddHouseCarrierCodeToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :house_carrier_code, :string
  end
end
