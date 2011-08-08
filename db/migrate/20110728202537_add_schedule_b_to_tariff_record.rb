class AddScheduleBToTariffRecord < ActiveRecord::Migration
  def self.up
    add_column :tariff_records, :schedule_b_1, :string
    add_column :tariff_records, :schedule_b_2, :string
    add_column :tariff_records, :schedule_b_3, :string
  end

  def self.down
    remove_column :tariff_records, :schedule_b_3
    remove_column :tariff_records, :schedule_b_2
    remove_column :tariff_records, :schedule_b_1
  end
end
