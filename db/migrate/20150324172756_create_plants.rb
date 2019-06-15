class CreatePlants < ActiveRecord::Migration
  def change
    create_table :plants do |t|
      t.string :name
      t.integer :company_id

      t.timestamps null: false
    end
    add_index :plants, :company_id
  end
end
