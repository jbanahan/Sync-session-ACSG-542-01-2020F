class AddIndexesToCustomValues < ActiveRecord::Migration
  def self.up
    add_index :custom_values, :string_value
    add_index :custom_values, :decimal_value
    add_index :custom_values, :integer_value
    add_index :custom_values, :date_value
    add_index :custom_values, :text_value, :length => 64
    add_index :custom_values, :boolean_value
  end

  def self.down
    remove_index :custom_values, :string_value
    remove_index :custom_values, :decimal_value
    remove_index :custom_values, :integer_value
    remove_index :custom_values, :date_value
    remove_index :custom_values, :text_value
    remove_index :custom_values, :boolean_value
  end
end
