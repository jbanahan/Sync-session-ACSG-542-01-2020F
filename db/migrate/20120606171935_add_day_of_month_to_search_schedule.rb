class AddDayOfMonthToSearchSchedule < ActiveRecord::Migration
  def self.up
    add_column :search_schedules, :day_of_month, :integer
  end

  def self.down
    remove_column :search_schedules, :day_of_month
  end
end
