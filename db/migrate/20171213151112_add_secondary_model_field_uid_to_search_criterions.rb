class AddSecondaryModelFieldUidToSearchCriterions < ActiveRecord::Migration
  def change
    add_column :search_criterions, :secondary_model_field_uid, :string
  end
end
