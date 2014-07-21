class AddCargoOnBoardDateToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :cargo_on_board_date, :date
  end
end
