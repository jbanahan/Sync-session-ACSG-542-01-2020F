class CreateProducts < ActiveRecord::Migration
  def self.up
    create_table :products do |t|
      t.string :unique_identifier
      t.string :part_number
      t.string :name
      t.string :description
      t.integer :vendor_id

      t.timestamps
    end
  end

  def self.down
    drop_table :products
  end
end
