class CreateTradeLanes < ActiveRecord::Migration
  def change
    create_table :trade_lanes do |t|
      t.integer :origin_country_id
      t.integer :destination_country_id
      t.decimal :tariff_adjustment_percentage, precision: 4, scale: 3
      t.text :notes

      t.timestamps
    end
    add_index :trade_lanes, :origin_country_id
    add_index :trade_lanes, :destination_country_id
    add_index :trade_lanes, [:origin_country_id, :destination_country_id], unique: true, name: 'unique_country_pair'
  end
end
