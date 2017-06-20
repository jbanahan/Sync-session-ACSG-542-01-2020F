class ReindexDelayedJobs < ActiveRecord::Migration
  def up
    if ActiveRecord::Base.connection.index_exists?(:delayed_jobs, [:priority, :run_at, :locked_by])
      remove_index :delayed_jobs, column: [:priority, :run_at, :locked_by]
    end

    add_index(:delayed_jobs, [:queue, :priority, :run_at, :locked_by], name: "index_delayed_jobs_on_queue_priority_run_at_locked_by")

    # Make sure anything currently in the job queue is set to get picked up by the default queue, otherwise we'd have to manually set the 
    # queue value before the restarted job queue will process them
    execute "UPDATE delayed_jobs SET queue = 'default'"
  end

  def down
    remove_index :delayed_jobs, name: "index_delayed_jobs_on_queue_priority_run_at_locked_by"
    add_index(:delayed_jobs, [:priority, :run_at, :locked_by])
    execute "UPDATE delayed_jobs SET queue = null"
  end
end
