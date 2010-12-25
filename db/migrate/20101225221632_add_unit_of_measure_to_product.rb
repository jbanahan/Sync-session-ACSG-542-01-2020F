class AddUnitOfMeasureToProduct < ActiveRecord::Migration
  def self.up
    add_column :products, :unit_of_measure, :string
  end

  def self.down
    remove_column :products, :unit_of_measure
  end
end
