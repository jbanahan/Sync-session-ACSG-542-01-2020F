class CreateOfficialTariffSpis < ActiveRecord::Migration
  def change
    create_table :official_tariff_spis do |t|
      t.integer :official_tariff_id
      t.string :spi_code
      t.decimal :rate, precision: 6, scale: 3
      t.string :rate_text

      t.timestamps
    end
    add_index :official_tariff_spis, :official_tariff_id
  end
end
