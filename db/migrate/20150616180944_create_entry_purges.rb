class CreateEntryPurges < ActiveRecord::Migration
  def change
    create_table :entry_purges do |t|
      t.string :broker_reference
      t.string :country_iso
      t.string :source_system
      t.datetime :date_purged

      t.timestamps null: false
    end
  end
end
