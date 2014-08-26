class AddRunIntervalToSchedulableJobs < ActiveRecord::Migration
  def change
    add_column :schedulable_jobs, :run_interval, :string
  end
end
