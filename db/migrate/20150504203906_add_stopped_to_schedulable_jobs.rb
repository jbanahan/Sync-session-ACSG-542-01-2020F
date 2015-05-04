class AddStoppedToSchedulableJobs < ActiveRecord::Migration
  def change
    add_column :schedulable_jobs, :stopped, :boolean
  end
end
