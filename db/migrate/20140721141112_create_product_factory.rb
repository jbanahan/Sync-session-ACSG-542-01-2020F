class CreateProductFactory < ActiveRecord::Migration
  def change
    create_table :product_factories do |t|
      t.integer :product_id
      t.integer :address_id
    end

    add_index :product_factories, [:product_id, :address_id], unique: true
    add_index :product_factories, [:address_id, :product_id]
  end
end
