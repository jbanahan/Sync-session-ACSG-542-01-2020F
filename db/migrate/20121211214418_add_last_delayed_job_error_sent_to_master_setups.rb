class AddLastDelayedJobErrorSentToMasterSetups < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :last_delayed_job_error_sent, :datetime, :default => ActiveSupport::TimeZone["UTC"].parse("2001-01-01 00:00:00")
  end

  def self.down
    remove_column :master_setups, :last_delayed_job_error_sent
  end
end
