class CreatePieceSets < ActiveRecord::Migration
  def self.up
    create_table :piece_sets do |t|
      t.references :order_line
      t.references :shipment
      t.references :product

      t.timestamps
    end
  end

  def self.down
    drop_table :piece_sets
  end
end
