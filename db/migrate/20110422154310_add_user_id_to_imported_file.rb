class AddUserIdToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :user_id, :integer
    migrate_user_ids
  end

  def self.down
    remove_column :imported_files, :user_id
  end

  def self.migrate_user_ids
    ImportedFile.all.each do |f|
      ss = f.search_setup
      unless ss.nil?
        f.user_id = ss.user_id
        f.save!
      end
    end
  end
end
