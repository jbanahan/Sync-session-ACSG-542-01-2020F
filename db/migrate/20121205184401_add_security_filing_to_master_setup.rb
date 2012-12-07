class AddSecurityFilingToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :security_filing_enabled, :boolean
  end

  def self.down
    remove_column :master_setups, :security_filing_enabled
  end
end
