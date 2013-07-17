class AddQuickSearchableToCustomDefinitions < ActiveRecord::Migration
  def change
    add_column :custom_definitions, :quick_searchable, :boolean
  end
end
