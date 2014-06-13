class AddEmailsToSchedulableJobs < ActiveRecord::Migration
  def up
    change_table :schedulable_jobs do |t|
      t.column :success_email, :string
      t.column :failure_email, :string
    end
  end

  def down
    change_table :schedulable_jobs do |t|
      t.remove :success_email
      t.remove :failure_email
    end
  end
end
