class CreateInventoryOuts < ActiveRecord::Migration
  def self.up
    create_table :inventory_outs do |t|

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :inventory_outs
  end
end
