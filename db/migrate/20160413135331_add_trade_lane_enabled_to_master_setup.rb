class AddTradeLaneEnabledToMasterSetup < ActiveRecord::Migration
  def change
    add_column :master_setups, :trade_lane_enabled, :boolean
  end
end
