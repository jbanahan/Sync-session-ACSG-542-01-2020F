class AddExpectedUpdateTimeToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :expected_update_time, :datetime
  end
end
