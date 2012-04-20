class AddIndexToSearchColumns < ActiveRecord::Migration
  def self.up
    add_index :search_columns, :imported_file_id
  end

  def self.down
    remove_index :search_columns, :imported_file_id
  end
end
