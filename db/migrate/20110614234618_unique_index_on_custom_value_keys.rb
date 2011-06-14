class UniqueIndexOnCustomValueKeys < ActiveRecord::Migration
  def self.up
    add_index :custom_values, [:customizable_id, :customizable_type, :custom_definition_id], {:unique=>true,:name=>:cv_unique_composite} 
  end

  def self.down
    remove_index :custom_values, :cv_unique_composite
  end
end
