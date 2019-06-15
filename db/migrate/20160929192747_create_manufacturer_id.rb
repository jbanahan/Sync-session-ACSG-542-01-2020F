class CreateManufacturerId < ActiveRecord::Migration
  def up
    create_table :manufacturer_ids do |t|
      t.string :mid
      t.string :name
      t.string :address_1
      t.string :address_2
      t.string :city
      t.string :postal_code
      t.string :country
      t.boolean :active

      t.timestamps null: false
    end

    add_index :manufacturer_ids, :mid
  end

  def down
    drop_table :manufacturer_ids
  end
end
