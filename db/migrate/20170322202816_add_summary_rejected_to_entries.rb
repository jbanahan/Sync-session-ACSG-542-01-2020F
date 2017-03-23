class AddSummaryRejectedToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :summary_rejected, :boolean
  end
end
