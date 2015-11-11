class AddEuropeanUnionToCountry < ActiveRecord::Migration
  def change
    add_column :countries, :european_union, :boolean
    execute "UPDATE countries SET european_union = 1 WHERE iso_code in ('AT','BE','BG','CY','CZ','DK','EE','FI','FR','DE','GR','HU','IE','IT','LV','LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','SE','GB')"
  end
end
