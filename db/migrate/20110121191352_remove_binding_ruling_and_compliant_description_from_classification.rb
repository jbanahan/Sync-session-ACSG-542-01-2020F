class RemoveBindingRulingAndCompliantDescriptionFromClassification < ActiveRecord::Migration
  def self.up
    remove_column :classifications, :binding_ruling_number
    remove_column :classifications, :compliant_description
  end

  def self.down
    add_column :classifications, :compliant_description, :text
    add_column :classifications, :binding_ruling_number, :string
  end
end
