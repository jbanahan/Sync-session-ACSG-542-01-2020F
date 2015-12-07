class AddLumberFieldsToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :currency, :string
    add_column :orders, :terms_of_payment, :string
    add_column :orders, :ship_from_id, :integer
    add_index :orders, :ship_from_id
  end
end
