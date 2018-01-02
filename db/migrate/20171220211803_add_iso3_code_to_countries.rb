class AddIso3CodeToCountries < ActiveRecord::Migration
  def change
    add_column :countries, :iso_3_code, :string
    add_index :countries, :iso_3_code
  end
end
