class CreateBusinessValidationScheduledJobs < ActiveRecord::Migration
  def self.up
    create_table :business_validation_scheduled_jobs do |t|
      t.integer :business_validation_schedule_id
      t.integer :validatable_id
      t.string :validatable_type
      t.datetime :run_date
      
      t.timestamps null: false
    end
  end

  def self.down
    drop_table :business_validation_scheduled_jobs
  end
end
