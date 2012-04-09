class AddSupportAgentToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :support_agent, :boolean
  end

  def self.down
    remove_column :users, :support_agent
  end
end
