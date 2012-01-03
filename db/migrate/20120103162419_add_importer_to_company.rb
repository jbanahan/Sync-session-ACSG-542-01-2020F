class AddImporterToCompany < ActiveRecord::Migration
  def self.up
    add_column :companies, :importer, :boolean
  end

  def self.down
    remove_column :companies, :importer
  end
end
