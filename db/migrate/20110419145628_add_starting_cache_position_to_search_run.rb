class AddStartingCachePositionToSearchRun < ActiveRecord::Migration
  def self.up
    add_column :search_runs, :starting_cache_position, :integer
  end

  def self.down
    remove_column :search_runs, :starting_cache_position
  end
end
