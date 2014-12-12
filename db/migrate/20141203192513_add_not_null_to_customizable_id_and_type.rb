class AddNotNullToCustomizableIdAndType < ActiveRecord::Migration
  def up
    change_column_null :custom_values, :customizable_id, false
    change_column_null :custom_values, :customizable_type, false
  end

  def down
    change_column_null :custom_values, :customizable_id, true
    change_column_null :custom_values, :customizable_type, true
  end
end
