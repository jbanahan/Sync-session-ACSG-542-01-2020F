class CreateTariffSetRecords < ActiveRecord::Migration
  def self.up
    create_table :tariff_set_records do |t|
      t.integer :tariff_set_id
      t.integer :country_id
      t.string  :hts_code
      t.text    :full_description
      t.text    :special_rates
      t.string  :general_rate
      t.text    :chapter
      t.text    :heading
      t.text    :sub_heading
      t.text    :remaining_description
      t.string  :add_valorem_rate
      t.string  :per_unit_rate
      t.string  :calculation_method
      t.string  :most_favored_nation_rate
      t.string  :general_preferential_tariff_rate
      t.string  :erga_omnes_rate
      t.string  :unit_of_measure
      t.string  :column_2_rate
      t.string  :import_regulations
      t.string  :export_regulations

      t.timestamps
    end

    add_index :tariff_set_records, :tariff_set_id
    add_index :tariff_set_records, :hts_code
  end

  def self.down
    drop_table :tariff_set_records
  end
end
