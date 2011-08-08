class CreateTariffSets < ActiveRecord::Migration
  def self.up
    create_table :tariff_sets do |t|
      t.integer :country_id
      t.string :label

      t.timestamps
    end
  end

  def self.down
    drop_table :tariff_sets
  end
end
