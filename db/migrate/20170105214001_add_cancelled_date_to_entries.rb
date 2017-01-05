class AddCancelledDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :cancelled_date, :datetime
  end
end
