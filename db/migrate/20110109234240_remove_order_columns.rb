class RemoveOrderColumns < ActiveRecord::Migration
  def self.up
    remove_column :orders, :buyer
    remove_column :orders, :season
  end

  def self.down
    add_column :orders, :season, :string
    add_column :orders, :buyer, :string
  end
end
