class AddLockedToCompany < ActiveRecord::Migration
  def self.up
    add_column :companies, :locked, :boolean
  end

  def self.down
    remove_column :companies, :locked
  end
end
