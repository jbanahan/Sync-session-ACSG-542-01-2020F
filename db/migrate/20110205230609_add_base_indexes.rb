class AddBaseIndexes < ActiveRecord::Migration
  def self.up
    add_index :custom_values, [:customizable_id, :customizable_type]
    add_index :custom_values, :custom_definition_id
    add_index :custom_definitions, :module_type
  end

  def self.down
    remove_index :custom_definitions, :module_type
    remove_index :custom_values, :custom_definition_id
    remove_index :custom_values, [:customizable_id, :customizable_type]
  end
end
