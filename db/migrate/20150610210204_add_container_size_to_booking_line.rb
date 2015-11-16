class AddContainerSizeToBookingLine < ActiveRecord::Migration
  def change
    add_column :booking_lines, :container_size, :string
  end
end
