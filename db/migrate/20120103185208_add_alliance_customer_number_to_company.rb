class AddAllianceCustomerNumberToCompany < ActiveRecord::Migration
  def self.up
    add_column :companies, :alliance_customer_number, :string
    add_index :companies, :alliance_customer_number, {:unique=>true, :name=>'alliance_cust_unique'}
  end

  def self.down
    remove_index :companies, :alliance_cust_unique
    remove_column :companies, :alliance_customer_number
  end
end
