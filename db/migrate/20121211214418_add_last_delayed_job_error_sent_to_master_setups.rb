class AddLastDelayedJobErrorSentToMasterSetups < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :last_delayed_job_error_sent, :datetime, :default => 1.hour.ago
  end

  def self.down
    remove_column :master_setups, :last_delayed_job_error_sent
  end
end
