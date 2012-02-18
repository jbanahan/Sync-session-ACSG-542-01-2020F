class AddRequestHostToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :request_host, :string
  end

  def self.down
    remove_column :master_setups, :request_host
  end
end
