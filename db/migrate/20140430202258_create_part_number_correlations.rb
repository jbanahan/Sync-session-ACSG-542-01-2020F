class CreatePartNumberCorrelations < ActiveRecord::Migration
  def up
    create_table :part_number_correlations do |t|
      t.integer :starting_row
      t.string :part_column
      t.string :part_regex
      t.string :entry_country_iso
      t.string :importers
      t.datetime :finished_time
      t.belongs_to :user

      t.timestamps
    end
  end

  def down
    drop_table :part_number_correlations
  end
end
