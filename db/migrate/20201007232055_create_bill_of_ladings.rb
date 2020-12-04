class CreateBillOfLadings < ActiveRecord::Migration
  def change
    create_table :bill_of_ladings do |t|
      t.references :entry
      t.string :bill_type
      t.string :bill_number
      # Self join allows linking of house bills to master bills
      t.references :bill_of_lading
      t.timestamps null: false
    end
  end
end
