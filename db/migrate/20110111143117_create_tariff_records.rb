class CreateTariffRecords < ActiveRecord::Migration
  def self.up
    create_table :tariff_records do |t|
      t.string :hts_1
      t.string :hts_2
      t.string :hts_3
      t.integer :classification_id

      t.timestamps
    end
  end

  def self.down
    drop_table :tariff_records
  end
end
