class AddNewBookingFieldsToShipments < ActiveRecord::Migration
  def up
    change_table :shipments, bulk:true do |t|
      t.string :booking_voyage
      t.datetime :packing_list_sent_date
      t.integer :packing_list_sent_by_id
    end
  end

  def down
    remove_column :shipments, :booking_voyage
    remove_column :shipments, :packing_list_sent_date
    remove_column :shipments, :packing_list_sent_by_id
  end

end
