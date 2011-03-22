class RemoveInventoryObjects < ActiveRecord::Migration
  def self.up
    remove_column :piece_sets, :inventory_in_id
    remove_column :piece_sets, :inventory_out_id
    drop_table :inventory_ins
    drop_table :inventory_outs
  end

  def self.down
    create_table :inventory_outs do |t|

      t.timestamps
    end
    
    create_table :inventory_ins do |t|

      t.timestamps
    end
    add_column :piece_sets, :inventory_out_id, :integer
    add_column :piece_sets, :inventory_in_id, :integer
  end
end
