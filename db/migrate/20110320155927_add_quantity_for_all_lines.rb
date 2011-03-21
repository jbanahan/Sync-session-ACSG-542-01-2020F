class AddQuantityForAllLines < ActiveRecord::Migration
  def self.up
    [:order_lines,:shipment_lines,:delivery_lines,:sales_order_lines].each do |t|
      add_column t, :quantity, :decimal, :precision => 13, :scale => 4
    end
  end

  def self.down
    [:sales_order_lines,:delivery_lines,:shipment_lines,:order_lines].each do |t|
      remove_column t, :quantity
    end
  end
end
