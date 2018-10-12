class AddAttributesToSpecialTariffCrossReferences < ActiveRecord::Migration
  def up
    change_table :special_tariff_cross_references, bulk:true do |t|
      t.string :import_country_iso
      t.integer :priority
      t.string :special_tariff_type
      t.boolean :suppress_from_feeds, default: false
    end
  end
end
