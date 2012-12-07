class AddNotesToSecurityFiling < ActiveRecord::Migration
  def self.up
    add_column :security_filings, :notes, :text
  end

  def self.down
    remove_column :security_filings, :notes
  end
end
