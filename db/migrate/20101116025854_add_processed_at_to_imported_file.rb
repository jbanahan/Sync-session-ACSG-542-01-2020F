class AddProcessedAtToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :processed_at, :datetime
  end

  def self.down
    remove_column :imported_files, :processed_at
  end
end
