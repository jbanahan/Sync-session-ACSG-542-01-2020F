class AddSalesOrderIdToHistory < ActiveRecord::Migration
  def self.up
    add_column :histories, :sales_order_id, :integer
  end

  def self.down
    remove_column :histories, :sales_order_id
  end
end
