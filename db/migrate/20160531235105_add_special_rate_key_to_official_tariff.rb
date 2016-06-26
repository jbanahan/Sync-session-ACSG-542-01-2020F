class AddSpecialRateKeyToOfficialTariff < ActiveRecord::Migration
  def up
    add_column :official_tariffs, :special_rate_key, :string
    execute "UPDATE official_tariffs SET special_rate_key = MD5(special_rates)"
    add_column :official_tariffs, :common_rate_decimal, :decimal, precision: 8, scale: 4
  end
  def down
    remove_column :official_tariffs, :common_rate_decimal
    remove_column :official_tariffs, :special_rate_key
  end
end
