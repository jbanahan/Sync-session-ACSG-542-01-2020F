class AddModuleTypeToImportedFile < ActiveRecord::Migration
  def self.up
    add_column :imported_files, :module_type, :string
    ImportedFile.all.each do |f|
      s = f.search_setup
      unless s.nil?
        f.module_type = s.module_type
        f.save!
      end
    end
  end

  def self.down
    remove_column :imported_files, :module_type
  end
end
