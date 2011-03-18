class CreateSearchSchedules < ActiveRecord::Migration
  def self.up
    create_table :search_schedules do |t|
      t.string :email_addresses
      t.string :ftp_server
      t.string :ftp_username
      t.string :ftp_password
      t.string :ftp_subfolder
      t.string :sftp_server
      t.string :sftp_username
      t.string :sftp_password
      t.string :sftp_subfolder
      t.boolean :run_monday
      t.boolean :run_tuesday
      t.boolean :run_wednesday
      t.boolean :run_thursday
      t.boolean :run_friday
      t.boolean :run_saturday
      t.boolean :run_sunday
      t.integer :run_hour
      t.datetime :last_start_time
      t.datetime :last_finish_time
      t.integer :search_setup_id

      t.timestamps
    end
  end

  def self.down
    drop_table :search_schedules
  end
end
