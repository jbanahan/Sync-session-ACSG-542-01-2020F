class AddVgmDatesToShipment < ActiveRecord::Migration
  def up
    change_table :shipments, bulk:true do |t|
      t.datetime :vgm_sent_date
      t.integer :vgm_sent_by_id
    end
  end

  def down
    remove_column :shipments, :vgm_sent_date
    remove_column :shipments, :vgm_sent_by_id
  end
end
