class AddImportLocationToCountries < ActiveRecord::Migration
  def self.up
    add_column :countries, :import_location, :boolean
  end

  def self.down
    remove_column :countries, :import_location
  end
end
