class CreateCanadianPgaLineIngredients < ActiveRecord::Migration
  def change
    create_table :canadian_pga_line_ingredients do |t|
      t.belongs_to :canadian_pga_line
      t.string :name
      t.decimal :quality, precision: 13, scale: 4
      t.decimal :quantity, precision: 13, scale: 4

      t.timestamps
    end
  end
end
