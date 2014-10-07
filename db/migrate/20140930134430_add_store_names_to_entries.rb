class AddStoreNamesToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :store_names, :text
  end
end
