class AddDeletedToEntitySnapshots < ActiveRecord::Migration
  def change
    add_column :entity_snapshots, :deleted, :boolean
  end
end
