class AddImportedFileIdToSearchRun < ActiveRecord::Migration
  def self.up
    add_column :search_runs, :imported_file_id, :integer
  end

  def self.down
    remove_column :search_runs, :imported_file_id
  end
end
