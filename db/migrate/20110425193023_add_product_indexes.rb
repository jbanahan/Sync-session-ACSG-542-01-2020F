class AddProductIndexes < ActiveRecord::Migration
  def self.up
    add_index :tariff_records, :classification_id
    add_index :classifications, :product_id
    add_index :classifications, :country_id
    add_index :products, :unique_identifier
    add_index :products, :name
  end

  def self.down
    remove_index :tariff_records, :classification_id
    remove_index :classifications, :product_id
    remove_index :classifications, :country_id
    remove_index :products, :unique_identifier
    remove_index :products, :name
  end
end
