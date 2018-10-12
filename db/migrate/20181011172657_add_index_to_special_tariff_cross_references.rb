class AddIndexToSpecialTariffCrossReferences < ActiveRecord::Migration
  def change
    add_index :special_tariff_cross_references, [:import_country_iso, :effective_date_start, :country_origin_iso, :special_tariff_type], name: "by_import_country_effective_date_country_origin_tariff_type"
  end
end
