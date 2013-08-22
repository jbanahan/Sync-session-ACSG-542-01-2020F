class AddStatsApiKeyToMasterSetup < ActiveRecord::Migration
  def change
    add_column :master_setups, :stats_api_key, :string
  end
end
