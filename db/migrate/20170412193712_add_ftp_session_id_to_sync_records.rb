class AddFtpSessionIdToSyncRecords < ActiveRecord::Migration
  def change
    add_column :sync_records, :ftp_session_id, :integer

    add_index :sync_records, :ftp_session_id
  end
end
