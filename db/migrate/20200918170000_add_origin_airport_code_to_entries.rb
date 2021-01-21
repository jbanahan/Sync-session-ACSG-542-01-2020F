class AddOriginAirportCodeToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :origin_airport_code, :string
  end
end
