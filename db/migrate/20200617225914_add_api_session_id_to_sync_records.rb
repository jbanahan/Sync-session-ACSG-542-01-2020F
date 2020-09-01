class AddApiSessionIdToSyncRecords < ActiveRecord::Migration
  def change
    change_table :sync_records, bulk: true do |t|
      t.column :api_session_id, :integer

      t.index :api_session_id
    end
  end
end
