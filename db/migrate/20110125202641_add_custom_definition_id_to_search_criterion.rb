class AddCustomDefinitionIdToSearchCriterion < ActiveRecord::Migration
  def self.up
    add_column :search_criterions, :custom_definition_id, :integer
  end

  def self.down
    remove_column :search_criterions, :custom_definition_id
  end
end
