class CustomFileIndexes < ActiveRecord::Migration
  def self.up
    add_index :custom_files, :file_type, {:name=>'ftype'}
    add_index :custom_file_records, :custom_file_id, {:name=>'cf_id'}
    add_index :custom_file_records, [:linked_object_id,:linked_object_type], {:name=>'linked_objects'}
  end

  def self.down
    remove_index :custom_file_records, :linked_objects
    remove_index :custom_file_records, :cf_id
    remove_index :custom_files, :ftype
  end
end
