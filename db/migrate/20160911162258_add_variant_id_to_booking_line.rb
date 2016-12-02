class AddVariantIdToBookingLine < ActiveRecord::Migration
  def change
    add_column :booking_lines, :variant_id, :integer
    add_index  :booking_lines, :variant_id
  end
end
