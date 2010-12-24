class CreateOrders < ActiveRecord::Migration
  def self.up
    create_table :orders do |t|
      t.string :order_number
      t.date :order_date
      t.string :buyer
      t.string :season
      t.references :division

      t.timestamps
    end
  end

  def self.down
    drop_table :orders
  end
end
