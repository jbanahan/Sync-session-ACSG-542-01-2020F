class AddReadOnlyToCustomDefinition < ActiveRecord::Migration
  def change
    add_column :custom_definitions, :read_only, :boolean
  end
end
