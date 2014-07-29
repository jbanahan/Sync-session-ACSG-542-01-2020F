class AddFobPointToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :fob_point, :string
    add_index :orders, :fob_point
  end
end
