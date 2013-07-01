class AddHtsIndicesToTariffRecord < ActiveRecord::Migration
  def change
    add_index :tariff_records, :hts_1
    add_index :tariff_records, :hts_2
    add_index :tariff_records, :hts_3
  end
end
