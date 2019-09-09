class AddConsigneePostalCodeConsigneeCountryCodeToEntries < ActiveRecord::Migration
  def change
    reversible do |direction|
      change_table(:entries, bulk: true) do |t|
        direction.up { migrate_up(t) }
        direction.down { migrate_down(t) }
      end
    end
  end

  def migrate_up t
    t.string :consignee_postal_code
    t.string :consignee_country_code
  end

  def migrate_down t
    t.remove :consignee_postal_code
    t.remove :consignee_country_code
  end
end
