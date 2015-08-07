class AddIsAddressToCustomDefinition < ActiveRecord::Migration
  def change
    add_column :custom_definitions, :is_address, :boolean
  end
end
