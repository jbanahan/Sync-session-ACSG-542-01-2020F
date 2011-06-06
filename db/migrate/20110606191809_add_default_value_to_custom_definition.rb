class AddDefaultValueToCustomDefinition < ActiveRecord::Migration
  def self.up
    add_column :custom_definitions, :default_value, :string
  end

  def self.down
    remove_column :custom_definitions, :default_value
  end
end
