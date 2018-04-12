class AddSellingAgentIdToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :selling_agent_id, :integer
  end
end
