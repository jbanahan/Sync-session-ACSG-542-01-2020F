class AddBookingLineToPieceSet < ActiveRecord::Migration
  def change
    add_column :piece_sets, :booking_line_id, :integer
  end
end
