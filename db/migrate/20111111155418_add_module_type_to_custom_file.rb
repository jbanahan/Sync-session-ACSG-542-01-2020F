class AddModuleTypeToCustomFile < ActiveRecord::Migration
  def self.up
    add_column :custom_files, :module_type, :string
  end

  def self.down
    remove_column :custom_files, :module_type
  end
end
