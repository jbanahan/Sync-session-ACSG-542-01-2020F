class AddVirtualFieldsToCustomDefinitions < ActiveRecord::Migration
  def up
    change_table(:custom_definitions, bulk: true) do |t|
      t.column :virtual_search_query, :text
      t.column :virtual_value_query, :text
    end
  end

  def down
    change_table(:custom_definitions, bulk: true) do |t|
      t.remove :virtual_search_query
      t.remove :virtual_value_query
    end
  end
end
