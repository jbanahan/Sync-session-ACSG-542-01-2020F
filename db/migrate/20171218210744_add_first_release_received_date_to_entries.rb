class AddFirstReleaseReceivedDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :first_release_received_date, :datetime
  end
end
