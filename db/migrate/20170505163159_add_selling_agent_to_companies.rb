class AddSellingAgentToCompanies < ActiveRecord::Migration
  def change
    add_column :companies, :selling_agent, :boolean
  end
end
