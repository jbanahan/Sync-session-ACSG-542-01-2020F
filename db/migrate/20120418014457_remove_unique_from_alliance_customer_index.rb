class RemoveUniqueFromAllianceCustomerIndex < ActiveRecord::Migration
  def self.up
    remove_index :companies, :name=>'alliance_cust_unique'
    add_index :companies, :alliance_customer_number
  end

  def self.down
  end
end
