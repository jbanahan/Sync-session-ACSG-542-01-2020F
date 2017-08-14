class AddUsFdaIndicatorToTariffSetRecords < ActiveRecord::Migration
  def change
    add_column :tariff_set_records, :fda_indicator, :string
  end
end
