class AddSystemCodeToCompany < ActiveRecord::Migration
  def self.up
    add_column :companies, :system_code, :string
  end

  def self.down
    remove_column :companies, :system_code
  end
end
