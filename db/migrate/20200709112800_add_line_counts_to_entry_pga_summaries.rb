class AddLineCountsToEntryPgaSummaries < ActiveRecord::Migration
  def up
    change_table(:entry_pga_summaries, bulk: true) do |t|
      t.integer :total_pga_lines
      t.integer :total_claimed_pga_lines
      t.integer :total_disclaimed_pga_lines
      t.remove :summary_line_count
    end

    add_column :pga_summaries, :disclaimed, :boolean
  end

  def down
    change_table(:entries, bulk: true) do |t|
      t.remove :total_pga_lines
      t.remove :total_claimed_pga_lines
      t.remove :total_disclaimed_pga_lines
      t.integer :summary_line_count
    end

    remove_column :pga_summaries, :disclaimed
  end
end
