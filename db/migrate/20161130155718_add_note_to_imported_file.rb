class AddNoteToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :note, :text
  end

  def self.down
    remove_column :imported_files, :note
  end
end
