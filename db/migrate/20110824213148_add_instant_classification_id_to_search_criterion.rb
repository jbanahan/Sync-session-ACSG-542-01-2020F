class AddInstantClassificationIdToSearchCriterion < ActiveRecord::Migration
  def self.up
    add_column :search_criterions, :instant_classification_id, :integer
  end

  def self.down
    remove_column :search_criterions, :instant_classification_id
  end
end
