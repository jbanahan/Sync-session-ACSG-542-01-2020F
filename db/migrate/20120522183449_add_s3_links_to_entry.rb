class AddS3LinksToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :last_file_bucket, :string
    add_column :entries, :last_file_path, :string
  end

  def self.down
    remove_column :entries, :last_file_path
    remove_column :entries, :last_file_bucket
  end
end
