class ChangeIndexOnSyncRecords < ActiveRecord::Migration
  def self.up
    # Need to speciy our own name here because by defualt rails generates a name that's over 64 chars long, and mysql doesn't apprreciate that
    add_index :sync_records, [:syncable_id, :syncable_type, :trading_partner, :fingerprint], unique: true, name: "index_sync_records_id_type_trading_partner_fingerprint"
    remove_index :sync_records, name: "index_sync_records_id_type_trading_partner"
  end

  def self.down
    # If up failed, we're not going to really be sure what index exists or not, so just double check before add/removing
    unless index_exists? :sync_records, [:syncable_id, :syncable_type, :trading_partner], name: "index_sync_records_id_type_trading_partner"
      add_index :sync_records, [:syncable_id, :syncable_type, :trading_partner], unique: true, name: "index_sync_records_id_type_trading_partner"
    end
    
    if index_exists? :sync_records, [:syncable_id, :syncable_type, :trading_partner, :fingerprint], name: "index_sync_records_id_type_trading_partner_fingerprint" 
      remove_index :sync_records, name: "index_sync_records_id_type_trading_partner_fingerprint"
    end
  end
end
