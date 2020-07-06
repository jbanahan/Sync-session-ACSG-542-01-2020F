class AddDefaultReportDateFormatToUser < ActiveRecord::Migration
  def up
    add_column :users, :default_report_date_format, :string
    add_column :search_setups, :date_format, :string
    add_column :search_schedules, :date_format, :string
  end

  def down
    remove_column :users, :default_report_date_format
    remove_column :search_setups, :date_format
    remove_column :search_schedules, :date_format
  end
end
