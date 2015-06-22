class AddDateTimeToCustomValue < ActiveRecord::Migration
  def change
    add_column :custom_values, :datetime_value, :datetime
    add_index :custom_values, :datetime_value
  end
end
