class AddIsUserToCustomDefinition < ActiveRecord::Migration
  def change
    add_column :custom_definitions, :is_user, :boolean
  end
end
