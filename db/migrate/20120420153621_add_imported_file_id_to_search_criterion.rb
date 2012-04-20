class AddImportedFileIdToSearchCriterion < ActiveRecord::Migration
  def self.up
    add_column :search_criterions, :imported_file_id, :integer
    add_index :search_criterions, :imported_file_id
  end

  def self.down
    remove_column :search_criterions, :imported_file_id
  end
end
