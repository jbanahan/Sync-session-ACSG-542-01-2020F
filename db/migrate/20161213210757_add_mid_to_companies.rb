class AddMidToCompanies < ActiveRecord::Migration
  def self.up
    add_column :companies, :mid, :string
  end

  def self.down 
    remove_column :companies, :mid
  end
end
