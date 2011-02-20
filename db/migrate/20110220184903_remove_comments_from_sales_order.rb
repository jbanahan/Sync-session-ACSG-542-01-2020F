class RemoveCommentsFromSalesOrder < ActiveRecord::Migration
  def self.up
    remove_column :sales_orders, :comments
  end

  def self.down
    add_column :sales_orders, :comments, :text
  end
end
