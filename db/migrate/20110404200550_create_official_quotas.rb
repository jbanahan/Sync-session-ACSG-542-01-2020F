class CreateOfficialQuotas < ActiveRecord::Migration
  def self.up
    create_table :official_quotas do |t|
      t.string :hts_code
      t.integer :country_id
      t.decimal :square_meter_equivalent_factor, :precision => 13, :scale => 4
      t.string :category
      t.string :unit_of_measure
      t.integer :official_tariff_id

      t.timestamps
    end
  end

  def self.down
    drop_table :official_quotas
  end
end
