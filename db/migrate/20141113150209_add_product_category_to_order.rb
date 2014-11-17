class AddProductCategoryToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :product_category, :string
  end
end
