class AddNoConcurrentJobsRunningToSchedulableJobs < ActiveRecord::Migration
  def change
    add_column :schedulable_jobs, :no_concurrent_jobs, :boolean
    add_column :schedulable_jobs, :running, :boolean
  end
end
