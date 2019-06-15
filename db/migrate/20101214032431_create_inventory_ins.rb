class CreateInventoryIns < ActiveRecord::Migration
  def self.up
    create_table :inventory_ins do |t|

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :inventory_ins
  end
end
