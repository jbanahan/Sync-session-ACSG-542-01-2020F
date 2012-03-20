class AddFenixCustomerNumberToCompany < ActiveRecord::Migration
  def self.up
    add_column :companies, :fenix_customer_number, :string
    add_index :companies, :fenix_customer_number
  end

  def self.down
    remove_index :companies, :fenix_customer_number
    remove_column :companies, :fenix_customer_number
  end
end
