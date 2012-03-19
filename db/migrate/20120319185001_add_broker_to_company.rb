class AddBrokerToCompany < ActiveRecord::Migration
  def self.up
    add_column :companies, :broker, :boolean
  end

  def self.down
    remove_column :companies, :broker
  end
end
