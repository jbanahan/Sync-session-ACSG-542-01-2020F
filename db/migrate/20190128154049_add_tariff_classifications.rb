class AddTariffClassifications < ActiveRecord::Migration
  def up
    create_table :tariff_classifications do |t|
      t.integer :country_id
      t.string :tariff_number
      t.date :effective_date_start
      t.date :effective_date_end
      t.decimal :number_of_reporting_units, precision: 10, scale: 2
      t.string :unit_of_measure_1
      t.string :unit_of_measure_2
      t.string :unit_of_measure_3
      t.string :duty_computation
      t.string :base_rate_indicator
      t.string :tariff_description
      t.boolean :countervailing_duty
      t.boolean :antidumping_duty
      t.boolean :blocked_record
      t.datetime :last_exported_from_source

      t.timestamps null: false
    end

    add_index :tariff_classifications, [:tariff_number, :country_id, :effective_date_start], name: "idx_tariff_classifications_on_number_country_effective_date", unique: true

    create_table :tariff_classification_rates do |t|
      t.integer :tariff_classification_id
      t.string :special_program_indicator
      t.decimal :rate_specific, precision: 14, scale: 8
      t.decimal :rate_advalorem, precision: 14, scale: 8
      t.decimal :rate_additional, precision: 14, scale: 8

      t.timestamps null: false
    end

    add_index :tariff_classification_rates, [:tariff_classification_id, :special_program_indicator], name: "idx_tariff_classification_rates_on_tariff_id_spi"
  end

  def down
    drop_table :tariff_classification_rates
    drop_table :tariff_classifications
  end
end
