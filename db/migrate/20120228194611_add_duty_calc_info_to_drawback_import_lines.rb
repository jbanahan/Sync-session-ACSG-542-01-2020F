class AddDutyCalcInfoToDrawbackImportLines < ActiveRecord::Migration
  def self.up
    add_column :drawback_import_lines, :entry_number, :string
    add_column :drawback_import_lines, :import_date, :date
    add_column :drawback_import_lines, :received_date, :date
    add_column :drawback_import_lines, :port_code, :string
    add_column :drawback_import_lines, :box_37_duty, :decimal, :precision=>10, :scale=>2
    add_column :drawback_import_lines, :box_40_duty, :decimal, :precision=>10, :scale=>2
    add_column :drawback_import_lines, :total_invoice_value, :decimal
    add_column :drawback_import_lines, :total_mpf, :decimal, :precision=>10, :scale=>2
    add_column :drawback_import_lines, :country_of_origin_code, :string
    add_column :drawback_import_lines, :part_number, :string
    add_column :drawback_import_lines, :hts_code, :string
    add_column :drawback_import_lines, :description, :string
    add_column :drawback_import_lines, :unit_of_measure, :string
    add_column :drawback_import_lines, :unit_price, :decimal, :precision=>16, :scale=>7
    add_column :drawback_import_lines, :rate, :decimal, :precision=>12, :scale=>8
    add_column :drawback_import_lines, :duty_per_unit, :decimal, :precision=>16, :scale=>9
    add_column :drawback_import_lines, :compute_code, :string
    add_column :drawback_import_lines, :ocean, :boolean
  end

  def self.down
    remove_column :drawback_import_lines, :ocean
    remove_column :drawback_import_lines, :compute_code
    remove_column :drawback_import_lines, :duty_per_unit
    remove_column :drawback_import_lines, :rate
    remove_column :drawback_import_lines, :unit_price
    remove_column :drawback_import_lines, :unit_of_measure
    remove_column :drawback_import_lines, :description
    remove_column :drawback_import_lines, :hts_number
    remove_column :drawback_import_lines, :part_number
    remove_column :drawback_import_lines, :country_of_origin_code
    remove_column :drawback_import_lines, :total_mpf
    remove_column :drawback_import_lines, :total_invoice_value
    remove_column :drawback_import_lines, :box_40_duty
    remove_column :drawback_import_lines, :box_37_duty
    remove_column :drawback_import_lines, :port_code
    remove_column :drawback_import_lines, :received_date
    remove_column :drawback_import_lines, :import_date
    remove_column :drawback_import_lines, :entry_number
  end
end
