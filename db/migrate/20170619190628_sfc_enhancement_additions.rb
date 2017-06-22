class SfcEnhancementAdditions < ActiveRecord::Migration
  def change
    change_table :shipments do |t|
      t.date :do_issued_at
      t.string :trucker_name
      t.date :port_last_free_day
      t.date :pickup_at
      t.datetime :in_warehouse_time
    end
  end
end
