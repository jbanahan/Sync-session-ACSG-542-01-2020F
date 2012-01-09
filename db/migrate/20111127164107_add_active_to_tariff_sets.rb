class AddActiveToTariffSets < ActiveRecord::Migration
  def self.up
    add_column :tariff_sets, :active, :boolean
    countries = []
    TariffSet.order("id DESC").each do |ts|
      ts.update_attributes(:active=>true) unless countries.include? ts.country_id
      countries << ts.country_id
    end
  end

  def self.down
    remove_column :tariff_sets, :active
  end
end
