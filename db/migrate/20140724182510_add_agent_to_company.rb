class AddAgentToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :agent, :boolean
    add_index :companies, :agent
  end
end
