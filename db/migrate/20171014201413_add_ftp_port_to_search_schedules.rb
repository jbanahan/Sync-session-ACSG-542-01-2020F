class AddFtpPortToSearchSchedules < ActiveRecord::Migration
  def change
    add_column :search_schedules, :ftp_port, :string
  end
end
