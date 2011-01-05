class CreateDeliveries < ActiveRecord::Migration
  def self.up
    create_table :deliveries do |t|
      t.integer :ship_from_id
      t.integer :ship_to_id
      t.integer :carrier_id
      t.string :reference
      t.string :bill_of_lading
      t.string :mode
      t.integer :customer_id

      t.timestamps
    end
  end

  def self.down
    drop_table :deliveries
  end
end
