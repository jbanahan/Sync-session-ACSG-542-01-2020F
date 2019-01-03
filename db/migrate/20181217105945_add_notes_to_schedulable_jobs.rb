class AddNotesToSchedulableJobs < ActiveRecord::Migration
  def self.up
    add_column :schedulable_jobs, :notes, :text
  end

  def self.down
    remove_column :schedulable_jobs, :notes
  end
end