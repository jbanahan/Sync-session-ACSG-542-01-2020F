class AddFtpPollingActiveToMasterSetups < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :ftp_polling_active, :boolean
  end

  def self.down
    remove_column :master_setups, :ftp_polling_active
  end
end
