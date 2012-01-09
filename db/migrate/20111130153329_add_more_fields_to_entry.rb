class AddMoreFieldsToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :po_numbers, :text
    add_column :entries, :mfids, :text
    add_column :entries, :total_invoiced_value, :decimal, :precision => 13, :scale => 2
    add_column :entries, :export_country_codes, :string
    add_column :entries, :origin_country_codes, :string
    add_column :entries, :vendor_names, :text
    add_column :entries, :special_program_indicators, :string
    add_column :entries, :export_date, :date
    add_column :entries, :merchandise_description, :string
    add_column :entries, :transport_mode_code, :string
    add_column :entries, :total_units, :decimal, :precision => 12, :scale => 3
    add_column :entries, :total_units_uoms, :string
    add_column :entries, :entry_port_code, :string
    add_column :entries, :ult_consignee_code, :string
    add_column :entries, :ult_consignee_name, :string
    add_column :entries, :gross_weight, :integer
    add_column :entries, :total_packages_uom, :string
    add_column :entries, :cotton_fee, :decimal, :precision => 11, :scale => 2
    add_column :entries, :hmf, :decimal, :precision => 11, :scale => 2
    add_column :entries, :mpf, :decimal, :precision => 11, :scale => 2
    add_index :entries, :po_numbers, :length => 10
    add_index :entries, :export_date
    add_index :entries, :transport_mode_code
    add_index :entries, :entry_port_code
    add_index :entries, :customer_references, :length => 10
  end

  def self.down
    remove_index :entries, :po_numbers
    remove_index :entries, :export_date
    remove_index :entries, :transport_mode_code
    remove_index :entries, :entry_port_code
    remove_index :entries, :customer_references

    remove_column :entries, :mpf
    remove_column :entries, :hmf
    remove_column :entries, :cotton_fee
    remove_column :entries, :total_packages_uom
    remove_column :entries, :gross_weight
    remove_column :entries, :ult_consignee_name
    remove_column :entries, :ult_consignee_code
    remove_column :entries, :entry_port_code
    remove_column :entries, :total_units_uoms
    remove_column :entries, :total_units
    remove_column :entries, :transport_mode_code
    remove_column :entries, :merchandise_description
    remove_column :entries, :export_date
    remove_column :entries, :special_program_indicators
    remove_column :entries, :vendor_names
    remove_column :entries, :origin_country_codes
    remove_column :entries, :export_country_codes
    remove_column :entries, :total_invoiced_value
    remove_column :entries, :mfids
    remove_column :entries, :po_numbers
  end
end
