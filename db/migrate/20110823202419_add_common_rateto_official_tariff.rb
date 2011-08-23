class AddCommonRatetoOfficialTariff < ActiveRecord::Migration
  def self.up
    add_column :official_tariffs, :common_rate, :string
    execute "UPDATE official_tariffs set common_rate = erga_omnes_rate WHERE country_id IN (SELECT ID FROM countries WHERE iso_code IN ('AT','BE','CY','CZ','DK','EE','FI','FR','DE','GR','HU','IE','IT','LV','LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','ES','SE','GB'));"
    execute "UPDATE official_tariffs set common_rate = most_favored_nation_rate WHERE country_id IN (SELECT ID FROM countries where iso_code IN ('CA','CN'));"
    execute "UPDATE official_tariffs set common_rate = general_rate where common_rate IS NULL"
  end

  def self.down
    remove_column :official_tariffs, :common_rate
  end
end
