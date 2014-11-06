class AddOrderViewTemplateToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :order_view_template, :string
  end
end
