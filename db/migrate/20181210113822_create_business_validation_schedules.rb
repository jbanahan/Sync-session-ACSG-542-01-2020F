class CreateBusinessValidationSchedules < ActiveRecord::Migration
  def self.up
    create_table :business_validation_schedules do |t|
      t.string :module_type
      t.string :model_field_uid
      t.string :operator
      t.integer :num_days

      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :business_validation_schedules
  end
end
