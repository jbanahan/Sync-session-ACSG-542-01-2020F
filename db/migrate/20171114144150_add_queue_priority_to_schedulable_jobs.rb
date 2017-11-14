class AddQueuePriorityToSchedulableJobs < ActiveRecord::Migration
  def change
    add_column :schedulable_jobs, :queue_priority, :integer
  end
end
