class CreateLocations < ActiveRecord::Migration
  def self.up
    create_table :locations do |t|
      t.string :locode
      t.string :name
      t.string :sub_division
      t.string :function
      t.string :status
      t.string :iata
      t.string :coordinates

      t.timestamps
    end
  end

  def self.down
    drop_table :locations
  end
end
