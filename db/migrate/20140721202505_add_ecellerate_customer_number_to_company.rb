class AddEcellerateCustomerNumberToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :ecellerate_customer_number, :string
    add_index :companies, :ecellerate_customer_number
  end
end
