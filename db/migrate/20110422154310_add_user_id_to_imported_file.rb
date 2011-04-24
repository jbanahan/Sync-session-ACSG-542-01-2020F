class AddUserIdToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :user_id, :integer
    migrate_user_ids
  end

  def self.down
    remove_column :imported_files, :user_id
  end

  def self.migrate_user_ids
    execute 'update imported_files set user_id = (select user_id from search_setups where search_setups.id = imported_files.search_setup_id);'
  end
end
