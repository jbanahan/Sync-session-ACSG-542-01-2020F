class RemoveLastAccessedFromSearchSetup < ActiveRecord::Migration
  def self.up
    remove_column :search_setups, :last_accessed
  end

  def self.down
    add_column :search_setups, :last_accessed, :datetime
  end
end
