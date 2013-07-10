class AddUseCountToOfficialTariff < ActiveRecord::Migration
  def change
    add_column :official_tariffs, :use_count, :integer
  end
end
