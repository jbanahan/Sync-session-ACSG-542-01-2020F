class AddTruckerNamesAndDeliverToNamesToEntry < ActiveRecord::Migration
  def change
    change_table(:entries) do |t|
      t.column :trucker_names, :text
      t.column :deliver_to_names, :text
    end
  end
end
