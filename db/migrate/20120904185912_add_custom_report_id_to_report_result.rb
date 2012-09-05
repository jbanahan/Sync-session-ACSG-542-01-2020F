class AddCustomReportIdToReportResult < ActiveRecord::Migration
  def self.up
    add_column :report_results, :custom_report_id, :integer
    add_index :report_results, :custom_report_id
  end

  def self.down
    remove_index :report_results, :custom_report_id
    remove_column :report_results, :custom_report_id
  end
end
