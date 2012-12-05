class AddSecurityFilingPermissionsToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :security_filing_view, :boolean
    add_column :users, :security_filing_edit, :boolean
    add_column :users, :security_filing_attach, :boolean
    add_column :users, :security_filing_comment, :boolean
  end

  def self.down
    remove_column :users, :security_filing_comment
    remove_column :users, :security_filing_attach
    remove_column :users, :security_filing_edit
    remove_column :users, :security_filing_view
  end
end
