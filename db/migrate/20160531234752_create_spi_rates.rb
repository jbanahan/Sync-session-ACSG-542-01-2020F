class CreateSpiRates < ActiveRecord::Migration
  def change
    create_table :spi_rates do |t|
      t.integer :country_id
      t.string :special_rate_key
      t.string :program_code
      t.decimal :rate, precision: 8, scale: 4
      t.string :rate_text

      t.timestamps null: false
    end
    add_index :spi_rates, :country_id
    add_index :spi_rates, :program_code
    add_index :spi_rates, [:special_rate_key,:country_id,:program_code], name: "srk_ici_pc"

  end
end
