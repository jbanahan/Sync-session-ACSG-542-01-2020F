class AddExcludeFileTimeStampToSearchSchedule < ActiveRecord::Migration
  def up
    add_column :search_schedules, :exclude_file_timestamp, :boolean
    execute "UPDATE search_schedules SET exclude_file_timestamp = true"
  end

  def down
    remove_column :search_schedules, :exclude_file_timestamp
  end
end
