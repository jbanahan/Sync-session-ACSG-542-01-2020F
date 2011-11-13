class AddCustomFileIdToSearchRun < ActiveRecord::Migration
  def self.up
    add_column :search_runs, :custom_file_id, :integer
    add_index :search_runs, :custom_file_id, :name=>'cf_id'
  end

  def self.down
    remove_index :search_runs, :name=>'cf_id'
    remove_column :search_runs, :custom_file_id
  end
end
