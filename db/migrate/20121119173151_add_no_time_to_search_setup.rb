class AddNoTimeToSearchSetup < ActiveRecord::Migration
  def self.up
    add_column :search_setups, :no_time, :boolean
  end

  def self.down
    remove_column :search_setups, :no_time
  end
end
