class AddDrawbackCustToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :drawback_customer, :boolean, null: false, default: false
  end
end
