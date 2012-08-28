class CreateImportedFileDownloads < ActiveRecord::Migration
  def self.up
    create_table :imported_file_downloads do |t|
      t.integer :imported_file_id
      t.integer :user_id
      t.string :additional_countries
      t.string :attached_file_name
      t.string :attached_content_type
      t.integer :attached_file_size
      t.datetime :attached_updated_at

      t.timestamps
    end
    add_index :imported_file_downloads, :imported_file_id
  end

  def self.down
    drop_table :imported_file_downloads
  end
end
