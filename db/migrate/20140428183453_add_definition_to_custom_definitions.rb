class AddDefinitionToCustomDefinitions < ActiveRecord::Migration
  def change
    add_column :custom_definitions, :definition, :text
  end
end
