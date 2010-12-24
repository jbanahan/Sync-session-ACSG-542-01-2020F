class CreateShipments < ActiveRecord::Migration
  def self.up
    create_table :shipments do |t|
      t.date :eta
      t.date :etd
      t.date :ata
      t.date :atd
      t.integer :ship_from_id
      t.integer :ship_to_id
      t.integer :carrier_id

      t.timestamps
    end
  end

  def self.down
    drop_table :shipments
  end
end
