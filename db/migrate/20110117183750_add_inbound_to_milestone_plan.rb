class AddInboundToMilestonePlan < ActiveRecord::Migration
  def self.up
    add_column :milestone_plans, :inbound, :boolean
  end

  def self.down
    remove_column :milestone_plans, :inbound
  end
end
