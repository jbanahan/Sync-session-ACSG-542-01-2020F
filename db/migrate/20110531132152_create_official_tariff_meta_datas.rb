class CreateOfficialTariffMetaDatas < ActiveRecord::Migration
  def self.up
    create_table :official_tariff_meta_datas do |t|
      t.string :hts_code
      t.integer :country_id
      t.boolean :auto_classify_ignore
      t.text :notes

      t.timestamps
    end

    add_index :official_tariff_meta_datas, [:country_id,:hts_code]
  end

  def self.down
    drop_table :official_tariff_meta_datas
  end
end
