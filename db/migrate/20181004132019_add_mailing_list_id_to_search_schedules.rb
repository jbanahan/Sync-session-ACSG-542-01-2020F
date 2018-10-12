class AddMailingListIdToSearchSchedules < ActiveRecord::Migration
  def change
    add_column :search_schedules, :mailing_list_id, :integer
  end
end
