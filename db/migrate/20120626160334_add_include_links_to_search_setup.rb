class AddIncludeLinksToSearchSetup < ActiveRecord::Migration
  def self.up
    add_column :search_setups, :include_links, :boolean
  end

  def self.down
    remove_column :search_setups, :include_links
  end
end
