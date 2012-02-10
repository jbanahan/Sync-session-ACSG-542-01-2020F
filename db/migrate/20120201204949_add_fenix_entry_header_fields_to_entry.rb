class AddFenixEntryHeaderFieldsToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :import_country_id, :integer
    add_column :entries, :importer_tax_id, :string
    add_column :entries, :cargo_control_number, :string
    add_column :entries, :ship_terms, :string
    add_column :entries, :direct_shipment_date, :date
    add_column :entries, :across_sent_date, :datetime
    add_column :entries, :pars_ack_date, :datetime
    add_column :entries, :pars_reject_date, :datetime
    add_column :entries, :cadex_accept_date, :datetime
    add_column :entries, :cadex_sent_date, :datetime
    add_column :entries, :employee_name, :string
    add_column :entries, :release_type, :string
    add_column :entries, :us_exit_port_code, :string
    add_column :entries, :origin_state_codes, :string
    add_column :entries, :export_state_codes, :string
    add_index :entries, :import_country_id
  end

  def self.down
    remove_index :entries, :import_country_id
    remove_column :entries, :export_state_codes
    remove_column :entries, :origin_state_codes
    remove_column :entries, :us_exit_port_code
    remove_column :entries, :release_type
    remove_column :entries, :employee_name
    remove_column :entries, :cadex_sent_date
    remove_column :entries, :cadex_accept_date
    remove_column :entries, :pars_reject_date
    remove_column :entries, :pars_ack_date
    remove_column :entries, :across_sent_date
    remove_column :entries, :direct_shipment_date
    remove_column :entries, :ship_terms
    remove_column :entries, :cargo_control_number
    remove_column :entries, :importer_tax_id
    remove_column :entries, :import_country_id
  end
end
