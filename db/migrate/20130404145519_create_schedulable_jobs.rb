class CreateSchedulableJobs < ActiveRecord::Migration
  def change
    create_table :schedulable_jobs do |t|
      t.boolean :run_monday
      t.boolean :run_tuesday
      t.boolean :run_wednesday
      t.boolean :run_thursday
      t.boolean :run_friday
      t.boolean :run_saturday
      t.boolean :run_sunday
      t.integer :run_hour
      t.integer :run_minute
      t.integer :day_of_month
      t.string :time_zone_name
      t.string :run_class
      t.text :opts

      t.timestamps
    end
  end
end
