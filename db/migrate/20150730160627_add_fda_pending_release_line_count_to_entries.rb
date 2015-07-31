class AddFdaPendingReleaseLineCountToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :fda_pending_release_line_count, :integer
  end
end
