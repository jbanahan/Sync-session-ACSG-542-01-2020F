class AddUsFdaIndicatorToOfficialTariffs < ActiveRecord::Migration
  def change
    add_column :official_tariffs, :fda_indicator, :string
  end
end
