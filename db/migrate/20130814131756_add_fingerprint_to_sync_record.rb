class AddFingerprintToSyncRecord < ActiveRecord::Migration
  def change
    add_column :sync_records, :fingerprint, :string, length: 32
  end
end
