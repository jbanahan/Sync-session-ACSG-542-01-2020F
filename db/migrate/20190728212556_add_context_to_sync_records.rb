class AddContextToSyncRecords < ActiveRecord::Migration
  def change
    add_column :sync_records, :context, :text
  end
end
