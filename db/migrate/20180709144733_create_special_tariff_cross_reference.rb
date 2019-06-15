class CreateSpecialTariffCrossReference < ActiveRecord::Migration
  def up
    create_table :special_tariff_cross_references do |t|
      t.string :hts_number
      t.string :special_hts_number
      t.string :country_origin_iso
      t.date :effective_date_start
      t.date :effective_date_end

      t.timestamps null: false
    end

    add_index :special_tariff_cross_references, [:hts_number, :country_origin_iso, :effective_date_start], name: "index_special_tariff_cross_references_on_hts_country_start_date"
  end

  def down
    drop_table :special_tariff_cross_references
  end
end
