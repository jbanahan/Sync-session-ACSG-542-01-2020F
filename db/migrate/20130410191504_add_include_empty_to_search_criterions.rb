class AddIncludeEmptyToSearchCriterions < ActiveRecord::Migration
  def change
    add_column :search_criterions, :include_empty, :boolean
  end
end
