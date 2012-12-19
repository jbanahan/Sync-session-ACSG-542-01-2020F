class AddNoTimeToCustomReports < ActiveRecord::Migration
  def self.up
    add_column :custom_reports, :no_time, :boolean
  end

  def self.down
    remove_column :custom_reports, :no_time
  end
end
