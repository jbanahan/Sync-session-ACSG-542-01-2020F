class AddSpecialTariffToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :special_tariff, :boolean
  end
end
