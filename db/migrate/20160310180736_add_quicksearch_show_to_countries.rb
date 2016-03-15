class AddQuicksearchShowToCountries < ActiveRecord::Migration
  def self.up
    add_column :countries, :quicksearch_show, :boolean
  end

  def self.down
    remove_column :countries, :quicksearch_show
  end
end
