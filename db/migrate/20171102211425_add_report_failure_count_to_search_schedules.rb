class AddReportFailureCountToSearchSchedules < ActiveRecord::Migration
  def change
    change_table :search_schedules, bulk:true do |t|
      t.integer :report_failure_count, :default => 0
      t.boolean :disabled
    end
  end
end
