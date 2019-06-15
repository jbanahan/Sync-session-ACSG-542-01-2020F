class CreateVariants < ActiveRecord::Migration
  def change
    create_table :variants do |t|
      t.references :product, null: false
      t.string :variant_identifier

      t.timestamps null: false
    end
    add_index :variants, :product_id
  end
end
