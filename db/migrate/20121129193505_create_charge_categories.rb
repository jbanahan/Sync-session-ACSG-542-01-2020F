class CreateChargeCategories < ActiveRecord::Migration
  def self.up
    create_table :charge_categories do |t|
      t.integer :company_id
      t.string :charge_code
      t.string :category

      t.timestamps
    end
    add_index :charge_categories, :company_id
  end

  def self.down
    drop_table :charge_categories
  end
end
