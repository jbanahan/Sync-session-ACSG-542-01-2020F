class CreateAddresses < ActiveRecord::Migration
  def self.up
    create_table :addresses do |t|
      t.string :name
      t.string :line_1
      t.string :line_2
      t.string :line_3
      t.string :city
      t.string :state
      t.string :postal_code
      t.boolean :ship_from
      t.boolean :ship_to
      t.references :company

      t.timestamps
    end
  end

  def self.down
    drop_table :addresses
  end
end
