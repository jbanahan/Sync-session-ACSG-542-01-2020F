class RemoveBindingRulingAndCompliantDescriptionFromClassification < ActiveRecord::Migration
  def self.up
    remove_column :classifications, :binding_ruling
    remove_column :classifications, :compliant_description
  end

  def self.down
    add_column :classifications, :compliant_description, :text
    add_column :classifications, :binding_ruling, :string
  end
end
