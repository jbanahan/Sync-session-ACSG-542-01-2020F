class AddBrokerIdToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :broker_id, :integer # rubocop:disable Rails/BulkChangeTable
    add_index :entries, :broker_id
  end
end
