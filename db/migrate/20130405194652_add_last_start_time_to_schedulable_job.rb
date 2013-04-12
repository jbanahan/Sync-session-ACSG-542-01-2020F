class AddLastStartTimeToSchedulableJob < ActiveRecord::Migration
  def change
    add_column :schedulable_jobs, :last_start_time, :datetime
  end
end
