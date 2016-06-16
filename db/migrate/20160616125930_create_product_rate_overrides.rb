class CreateProductRateOverrides < ActiveRecord::Migration
  def change
    create_table :product_rate_overrides do |t|
      t.integer :product_id
      t.integer :origin_country_id
      t.integer :destination_country_id
      t.decimal :rate, precision: 8, scale: 4
      t.date :start_date
      t.date :end_date
      t.text :notes

      t.timestamps
    end
    add_index :product_rate_overrides, :product_id, name: 'prod_id'
    add_index :product_rate_overrides, [:origin_country_id,:destination_country_id], name: 'countries'
    add_index :product_rate_overrides, [:start_date, :end_date], name: 'start_end'
  end
end
