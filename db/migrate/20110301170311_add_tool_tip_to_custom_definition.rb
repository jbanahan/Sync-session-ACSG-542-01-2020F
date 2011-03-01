class AddToolTipToCustomDefinition < ActiveRecord::Migration
  def self.up
    add_column :custom_definitions, :tool_tip, :string
  end

  def self.down
    remove_column :custom_definitions, :tool_tip
  end
end
