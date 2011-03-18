class AddLineNumberToTariffRecord < ActiveRecord::Migration
  def self.up
    add_column :tariff_records, :line_number, :integer
    TariffRecord.reset_column_information
    TariffRecord.all.each do |tr|
      tr.auto_set_line_number
      tr.save!
    end
  end

  def self.down
    remove_column :tariff_records, :line_number
  end
end
