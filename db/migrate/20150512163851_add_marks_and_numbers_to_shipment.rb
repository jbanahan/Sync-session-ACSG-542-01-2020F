class AddMarksAndNumbersToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :marks_and_numbers, :string
  end
end
