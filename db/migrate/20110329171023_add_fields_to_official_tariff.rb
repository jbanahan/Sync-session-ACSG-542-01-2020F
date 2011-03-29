class AddFieldsToOfficialTariff < ActiveRecord::Migration
  def self.up
    add_column :official_tariffs, :chapter, :string, :limit => 800
    add_column :official_tariffs, :heading, :string, :limit => 800
    add_column :official_tariffs, :sub_heading, :string, :limit => 800
    add_column :official_tariffs, :remaining_description, :string, :limit => 800
    add_column :official_tariffs, :add_valorem_rate, :string
    add_column :official_tariffs, :per_unit_rate, :string
    add_column :official_tariffs, :calculation_method, :string
    add_column :official_tariffs, :most_favored_nation_rate, :string
    add_column :official_tariffs, :general_preferential_tariff_rate, :string
    add_column :official_tariffs, :erga_omnes_rate, :string
    remove_column :official_tariffs, :unit_of_quantity
    add_column :official_tariffs, :unit_of_measure, :string
    remove_column :official_tariffs, :rate_2
    add_column :official_tariffs, :column_2_rate, :string
  end

  def self.down
    remove_column :official_tariffs, :column_2_rate
    add_column :official_tariffs, :rate_2, :string
    remove_column :official_tariffs, :unit_of_measure
    add_column :official_tariffs, :unit_of_quantity, :string
    remove_column :official_tariffs, :erga_omnes_rate
    remove_column :official_tariffs, :general_preferential_tariff_rate
    remove_column :official_tariffs, :most_favored_nation_rate
    remove_column :official_tariffs, :calculation_method
    remove_column :official_tariffs, :per_unit_rate
    remove_column :official_tariffs, :add_valorem_rate
    remove_column :official_tariffs, :remaining_description
    remove_column :official_tariffs, :sub_heading
    remove_column :official_tariffs, :heading
    remove_column :official_tariffs, :chapter
  end
end
