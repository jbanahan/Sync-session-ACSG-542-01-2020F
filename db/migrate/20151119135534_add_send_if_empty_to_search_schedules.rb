class AddSendIfEmptyToSearchSchedules < ActiveRecord::Migration
  def self.up
    add_column :search_schedules, :send_if_empty, :boolean
  end

  def self.down
    remove_column :search_schedules, :send_if_empty
  end
end
