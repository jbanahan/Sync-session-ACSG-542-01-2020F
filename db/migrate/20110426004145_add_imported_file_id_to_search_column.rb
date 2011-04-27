class AddImportedFileIdToSearchColumn < ActiveRecord::Migration
  def self.up
    add_column :search_columns, :imported_file_id, :integer
  end

  def self.down
    remove_column :search_columns, :imported_file_id
  end
end
