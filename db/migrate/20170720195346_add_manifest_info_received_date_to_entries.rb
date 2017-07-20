class AddManifestInfoReceivedDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :manifest_info_received_date, :datetime
  end
end
