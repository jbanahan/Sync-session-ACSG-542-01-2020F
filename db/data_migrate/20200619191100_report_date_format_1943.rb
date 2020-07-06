class ReportDateFormat1943 < ActiveRecord::Migration
  def up
    users = User.where(default_report_date_format: nil).where("email NOT LIKE '%.duplicate%'")
    users.find_each do |u|
      u.update!(default_report_date_format: "yyyy-mm-dd")
      u.create_snapshot User.integration, nil, "SOW 1943 - Setting default report date value."
    end

    search_setups = SearchSetup.where(date_format: nil)
    search_setups.update_all(date_format: "yyyy-mm-dd") # rubocop:disable Rails/SkipsModelValidations

    search_schedules = SearchSchedule.where(date_format: nil)
    search_schedules.update_all(date_format: "yyyy-mm-dd") # rubocop:disable Rails/SkipsModelValidations
  end

  def down
    # Does nothing.
  end
end