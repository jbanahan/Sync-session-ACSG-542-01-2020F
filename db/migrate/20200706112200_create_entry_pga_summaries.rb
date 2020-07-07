class CreateEntryPgaSummaries < ActiveRecord::Migration
  def self.up
    create_table :entry_pga_summaries do |t|
      t.integer :entry_id, null: false
      t.string :agency_code, null: false
      t.integer :summary_line_count

      t.timestamps
    end

    add_index(:entry_pga_summaries, [:entry_id])
  end

  def self.down
    drop_table :entry_pga_summaries
  end
end