class AddSearchSetupIdToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :search_setup_id, :integer
  end

  def self.down
    remove_column :imported_files, :search_setup_id
  end
end
