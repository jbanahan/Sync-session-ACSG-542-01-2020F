class AddProtocolToSearchSchedules < ActiveRecord::Migration
  def up
    add_column :search_schedules, :protocol, :string
    if column_exists? :search_schedules, :sftp_server
      remove_column :search_schedules, :sftp_server
      remove_column :search_schedules, :sftp_username
      remove_column :search_schedules, :sftp_password
      remove_column :search_schedules, :sftp_subfolder
    end
  end

  def down
    remove_column :search_schedules, :protocol
  end
end
