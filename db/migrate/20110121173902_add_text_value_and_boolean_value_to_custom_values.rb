class AddTextValueAndBooleanValueToCustomValues < ActiveRecord::Migration
  def self.up
    add_column :custom_values, :text_value, :text
    add_column :custom_values, :boolean_value, :boolean
  end

  def self.down
    remove_column :custom_values, :boolean_value
    remove_column :custom_values, :text_value
  end
end
