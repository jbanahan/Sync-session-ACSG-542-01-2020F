class CreateHistories < ActiveRecord::Migration
  def self.up
    create_table :histories do |t|
      t.integer :order_id
      t.integer :shipment_id
      t.integer :product_id
      t.integer :company_id
      t.integer :user_id
      t.integer :order_line_id
      t.string :type
      t.datetime :walked

      t.timestamps
    end
  end

  def self.down
    drop_table :histories
  end
end
