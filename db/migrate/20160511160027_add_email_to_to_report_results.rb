class AddEmailToToReportResults < ActiveRecord::Migration
  def change
    add_column :report_results, :email_to, :string
  end
end
