class AddFieldsToOrderLineForLenox < ActiveRecord::Migration
  def change
    add_column :order_lines, :currency, :string
    add_column :order_lines, :country_of_origin, :string
    add_column :order_lines, :hts, :string
    add_column :orders, :mode, :string
  end
end
