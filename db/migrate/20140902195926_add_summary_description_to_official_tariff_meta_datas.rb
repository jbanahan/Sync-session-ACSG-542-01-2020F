class AddSummaryDescriptionToOfficialTariffMetaDatas < ActiveRecord::Migration
  def change
    add_column :official_tariff_meta_datas, :summary_description, :string
  end
end
