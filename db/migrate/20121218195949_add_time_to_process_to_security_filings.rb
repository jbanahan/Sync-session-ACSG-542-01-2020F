class AddTimeToProcessToSecurityFilings < ActiveRecord::Migration
  def self.up
    add_column :security_filings, :time_to_process, :integer
  end

  def self.down
    remove_column :security_filings, :time_to_process
  end
end
