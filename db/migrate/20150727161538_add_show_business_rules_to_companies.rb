class AddShowBusinessRulesToCompanies < ActiveRecord::Migration
  def change
    add_column :companies, :show_business_rules, :boolean
  end
end
