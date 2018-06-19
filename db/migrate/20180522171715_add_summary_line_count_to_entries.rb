class AddSummaryLineCountToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :summary_line_count, :integer
  end
end
