class FixReservedWordColumns < ActiveRecord::Migration
  def self.up
    rename_column :history_details, :key, :source_key
    rename_column :messages, :read, :viewed
    rename_column :import_config_mappings, :column, :column_rank
    rename_column :search_criterions, :condition, :operator
  end

  def self.down
    rename_column :history_details,  :source_key, :key
    rename_column :messages, :viewed, :read
    rename_column :import_config_mappings, :column_rank, :column
    rename_column :search_criterions, :operator, :condition
  end
end
