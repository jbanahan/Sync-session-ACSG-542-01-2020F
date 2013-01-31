class ChangeDelayedJobFieldSizes < ActiveRecord::Migration
  def change
    change_column :delayed_jobs, :handler, :text, :limit => 4294967295
    change_column :delayed_jobs, :last_error, :text, :limit => 4294967295
  end
end
