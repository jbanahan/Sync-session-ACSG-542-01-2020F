class CreateOfficialTariffs < ActiveRecord::Migration
  def self.up
    create_table :official_tariffs do |t|
      t.integer :country_id
      t.string :hts_code
      t.text :full_description
      t.string :special_rates
      t.string :unit_of_quantity
      t.string :general_rate
      t.string :rate_2

      t.timestamps
    end
  end

  def self.down
    drop_table :official_tariffs
  end
end
