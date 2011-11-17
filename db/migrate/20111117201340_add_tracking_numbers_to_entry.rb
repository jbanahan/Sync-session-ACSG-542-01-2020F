class AddTrackingNumbersToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :master_bills_of_lading, :text
    add_column :entries, :house_bills_of_lading, :text
    add_column :entries, :sub_house_bills_of_lading, :text
    add_column :entries, :it_numbers, :text
  end

  def self.down
    remove_column :entries, :it_numbers
    remove_column :entries, :sub_house_bills_of_lading
    remove_column :entries, :house_bills_of_lading
    remove_column :entries, :master_bills_of_lading
  end
end
