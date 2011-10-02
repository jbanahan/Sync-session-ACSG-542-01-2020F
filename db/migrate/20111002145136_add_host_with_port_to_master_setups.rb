class AddHostWithPortToMasterSetups < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :host_with_port, :string
  end

  def self.down
    remove_column :master_setups, :host_with_port
  end
end
