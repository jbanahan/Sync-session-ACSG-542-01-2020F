class AddProductLinesToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :product_lines, :string
  end
end
