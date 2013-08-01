class RemoveReadOnlyFromCustomDefinition < ActiveRecord::Migration
  def up
    remove_column :custom_definitions, :read_only
  end

  def down
    add_column :custom_definitions, :read_only, :boolean
  end
end
