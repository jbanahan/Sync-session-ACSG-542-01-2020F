class AddLastEventToSecurityFiling < ActiveRecord::Migration
  def self.up
    add_column :security_filings, :last_event, :datetime
  end

  def self.down
    remove_column :security_filings, :last_event
  end
end
