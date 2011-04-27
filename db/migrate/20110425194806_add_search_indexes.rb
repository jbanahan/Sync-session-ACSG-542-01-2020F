class AddSearchIndexes < ActiveRecord::Migration
  def self.up
    add_index :sort_criterions, :search_setup_id
    add_index :search_setups, [:user_id, :module_type]
    add_index :search_schedules, :search_setup_id
    add_index :search_runs, [:user_id, :last_accessed]
    add_index :search_criterions, :search_setup_id
    add_index :search_columns, :search_setup_id
  end

  def self.down
    remove_index :sort_criterions, :search_setup_id
    remove_index :search_setups, [:user_id, :module_type]
    remove_index :search_schedules, :search_setup_id
    remove_index :search_runs, [:user_id, :last_accessed]
    remove_index :search_criterions, :search_setup_id
    remove_index :search_columns, :search_setup_id
  end
end
