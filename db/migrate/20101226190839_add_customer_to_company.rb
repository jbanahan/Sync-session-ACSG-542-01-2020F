class AddCustomerToCompany < ActiveRecord::Migration
  def self.up
    add_column :companies, :customer, :boolean
  end

  def self.down
    remove_column :companies, :customer
  end
end
