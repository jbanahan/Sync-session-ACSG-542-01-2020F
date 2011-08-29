class AddInstantClassificationIdToClassification < ActiveRecord::Migration
  def self.up
    add_column :classifications, :instant_classification_id, :integer
  end

  def self.down
    remove_column :classifications, :instant_classification_id
  end
end
