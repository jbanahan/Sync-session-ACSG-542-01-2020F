class AddFishAndWildlifeDatesToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :fish_and_wildlife_transmitted_date, :datetime
    add_column :entries, :fish_and_wildlife_secure_facility_date, :datetime
    add_column :entries, :fish_and_wildlife_hold_date, :datetime
    add_column :entries, :fish_and_wildlife_hold_release_date, :datetime
  end
end
