class ChangeSearchCriterionToUseUid < ActiveRecord::Migration
  def self.up
    remove_column :search_criterions, :module_type
    remove_column :search_criterions, :field_name
    add_column :search_criterions, :model_field_uid, :string
  end

  def self.down
    remove_column :search_criterions, :model_field_uid
    add_column :search_criterions, :field_name, :string
    add_column :search_criterions, :module_type, :string
  end
end
