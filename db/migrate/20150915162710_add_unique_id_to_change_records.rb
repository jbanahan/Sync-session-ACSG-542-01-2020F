class AddUniqueIdToChangeRecords < ActiveRecord::Migration
  def change
    add_column :change_records, :unique_identifier, :string
  end
end
