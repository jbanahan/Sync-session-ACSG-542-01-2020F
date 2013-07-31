class AddConsigneeToCompanies < ActiveRecord::Migration
  def change
    add_column :companies, :consignee, :boolean
  end
end
