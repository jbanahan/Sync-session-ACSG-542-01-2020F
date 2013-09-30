class AddLockedByToDelayedJobsIndex < ActiveRecord::Migration
  def up
    # The standard dj index isn't named according to rails index naming conventions
    if index_exists? :delayed_jobs, [:priority, :run_at], name: "delayed_jobs_priority"
      remove_index :delayed_jobs, name: "delayed_jobs_priority"
    end
    add_index :delayed_jobs, [:priority, :run_at, :locked_by]
  end

  def down
    if index_exists? :delayed_jobs, [:priority, :run_at, :locked_by]
      remove_index :delayed_jobs, [:priority, :run_at, :locked_by]
    end

    unless index_exists? :delayed_jobs, [:priority, :run_at], name: "delayed_jobs_priority"
      add_index :delayed_jobs, [:priority, :run_at], name: "delayed_jobs_priority"
    end
  end
end
