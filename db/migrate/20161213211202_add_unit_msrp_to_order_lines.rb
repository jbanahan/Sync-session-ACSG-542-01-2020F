class AddUnitMsrpToOrderLines < ActiveRecord::Migration
  def self.up
    add_column :order_lines, :unit_msrp, :decimal, :precision => 13, :scale => 4
  end

  def self.down
    remove_column :order_lines, :unit_msrp
  end
end
