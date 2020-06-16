class CreateSystemDates < ActiveRecord::Migration
  def self.up
    create_table :system_dates do |t|
      t.string :date_type, null: false
      t.integer :company_id
      t.datetime :start_date
      t.datetime :end_date

      t.timestamps
    end

    add_index(:system_dates, [:date_type, :company_id], unique: true)
  end

  def self.down
    drop_table :system_dates
  end
end
