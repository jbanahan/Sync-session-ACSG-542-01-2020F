class ChangeSearchRunForQuerySearch < ActiveRecord::Migration
  def up
    add_column :search_runs, :page, :integer
    add_column :search_runs, :per_page, :integer
    remove_column :search_runs, :position
    remove_column :search_runs, :result_cache 
  end

  def down
    remove_column :search_runs, :page
    remove_column :search_runs, :per_page
    add_column :search_runs, :position, :integer
    add_column :search_runs, :result_cache, :text
  end
end
