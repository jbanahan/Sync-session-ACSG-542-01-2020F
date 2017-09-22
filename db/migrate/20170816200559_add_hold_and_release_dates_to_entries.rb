class AddHoldAndReleaseDatesToEntries < ActiveRecord::Migration
  def up
    change_table :entries, bulk:true do |t|
      t.datetime :one_usg_date
      t.datetime :ams_hold_date
      t.datetime :ams_hold_release_date
      t.datetime :aphis_hold_date
      t.datetime :aphis_hold_release_date
      t.datetime :atf_hold_date
      t.datetime :atf_hold_release_date
      t.datetime :cargo_manifest_hold_date
      t.datetime :cargo_manifest_hold_release_date
      t.datetime :cbp_hold_date
      t.datetime :cbp_hold_release_date
      t.datetime :cbp_intensive_hold_date
      t.datetime :cbp_intensive_hold_release_date
      t.datetime :ddtc_hold_date
      t.datetime :ddtc_hold_release_date
      t.datetime :fda_hold_date
      t.datetime :fda_hold_release_date
      t.datetime :fsis_hold_date
      t.datetime :fsis_hold_release_date
      t.datetime :nhtsa_hold_date
      t.datetime :nhtsa_hold_release_date
      t.datetime :nmfs_hold_date
      t.datetime :nmfs_hold_release_date
      t.datetime :usda_hold_date
      t.datetime :usda_hold_release_date
      t.datetime :other_agency_hold_date
      t.datetime :other_agency_hold_release_date
      
      # derived values
      t.boolean :on_hold
      t.datetime :hold_date
      t.datetime :hold_release_date
    end
  end

  def down
    change_table :entries, bulk:true do |t|
      t.remove :one_usg_date
      t.remove :ams_hold_date
      t.remove :ams_hold_release_date
      t.remove :aphis_hold_date
      t.remove :aphis_hold_release_date
      t.remove :atf_hold_date
      t.remove :atf_hold_release_date
      t.remove :cargo_manifest_hold_date
      t.remove :cargo_manifest_hold_release_date
      t.remove :cbp_hold_date
      t.remove :cbp_hold_release_date
      t.remove :cbp_intensive_hold_date
      t.remove :cbp_intensive_hold_release_date
      t.remove :ddtc_hold_date
      t.remove :ddtc_hold_release_date
      t.remove :fda_hold_date
      t.remove :fda_hold_release_date
      t.remove :fsis_hold_date
      t.remove :fsis_hold_release_date
      t.remove :nhtsa_hold_date
      t.remove :nhtsa_hold_release_date
      t.remove :nmfs_hold_date
      t.remove :nmfs_hold_release_date
      t.remove :usda_hold_date
      t.remove :usda_hold_release_date
      t.remove :other_agency_hold_date
      t.remove :other_agency_hold_release_date
      
      # derived values
      t.remove :on_hold
      t.remove :hold_date
      t.remove :hold_release_date
    end
  end
end
