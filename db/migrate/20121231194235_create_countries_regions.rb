class CreateCountriesRegions < ActiveRecord::Migration
  def change
    create_table :countries_regions do |t|
      t.integer :country_id
      t.integer :region_id
    end
    add_index :countries_regions, :country_id
    add_index :countries_regions, [:region_id,:country_id], :unique=>true
  end
end
