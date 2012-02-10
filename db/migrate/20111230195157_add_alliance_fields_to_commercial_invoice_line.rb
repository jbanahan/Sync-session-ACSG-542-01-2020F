class AddAllianceFieldsToCommercialInvoiceLine < ActiveRecord::Migration
  def self.up
    remove_column :commercial_invoice_lines, :duty_rate
    remove_column :commercial_invoice_lines, :part_description
    remove_column :commercial_invoice_lines, :hts_number
    remove_column :commercial_invoice_lines, :units
    add_column :commercial_invoice_lines, :units, :decimal, :precision=>12, :scale=>3
    add_column :commercial_invoice_lines, :mid, :string
    add_column :commercial_invoice_lines, :country_origin_code, :string
    add_column :commercial_invoice_lines, :charges, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoice_lines, :country_export_code, :string
    add_column :commercial_invoice_lines, :related_parties, :boolean
    add_column :commercial_invoice_lines, :vendor_name, :string
    add_column :commercial_invoice_lines, :volume, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoice_lines, :computed_value, :decimal, :precision=>13, :scale=>2
    add_column :commercial_invoice_lines, :computed_adjustments, :decimal, :precision=>13, :scale=>2
    add_column :commercial_invoice_lines, :computed_net_value, :decimal, :precision=>13, :scale=>2
    add_column :commercial_invoice_lines, :computed_duty_percentage, :decimal, :precision=>8, :scale=>2
    add_column :commercial_invoice_lines, :mpf, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoice_lines, :hmf, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoice_lines, :cotton_fee, :decimal, :precision=>11, :scale=>2


  end

  def self.down
    remove_column :commercial_invoice_lines, :computed_value
    remove_column :commercial_invoice_lines, :computed_adjustments
    remove_column :commercial_invoice_lines, :computed_net_value
    remove_column :commercial_invoice_lines, :computed_duty_percentage
    remove_column :commercial_invoice_lines, :mpf
    remove_column :commercial_invoice_lines, :hmf
    remove_column :commercial_invoice_lines, :cotton_fee
    remove_column :commercial_invoice_lines, :volume
    remove_column :commercial_invoice_lines, :vendor_name
    remove_column :commercial_invoice_lines, :related_parties
    remove_column :commercial_invoice_lines, :country_export_code
    remove_column :commercial_invoice_lines, :charges
    remove_column :commercial_invoice_lines, :country_origin_code
    remove_column :commercial_invoice_lines, :mid
    remove_column :commercial_invoice_lines, :units
    add_column :commercial_invoice_lines, :units, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoice_lines, :hts_number, :string
    add_column :commercial_invoice_lines, :part_description, :string
    add_column :commercial_invoice_lines, :duty_rate, :decimal, :precision=>11, :scale=>2
  end
end
