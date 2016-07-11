class CreateTradePreferencePrograms < ActiveRecord::Migration
  def change
    create_table :trade_preference_programs do |t|
      t.string :name
      t.integer :origin_country_id
      t.integer :destination_country_id
      t.string :tariff_identifier
      t.decimal :tariff_adjustment_percentage, precision: 4, scale: 3

      t.timestamps
    end
    add_index :trade_preference_programs, :origin_country_id, name: 'tpp_origin'
    add_index :trade_preference_programs, :destination_country_id, name: 'tpp_destination'
  end
end
