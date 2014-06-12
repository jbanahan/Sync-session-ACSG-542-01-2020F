class CustomReportContainerListing < CustomReport
  def self.template_name
    "Container Listing"
  end
  def self.description
    "Show all entries with a row for each container"
  end
  def self.column_fields_available user
    [
      :ent_brok_ref,:ent_entry_num,:ent_release_date,:ent_cust_num,:ent_cust_name,
      :ent_type, :ent_arrival_date, :ent_filed_date, :ent_first_release,
      :ent_mbols, :ent_hbols, :ent_sbols, :ent_it_numbers, :ent_carrier_code,
      :ent_customer_references, :ent_po_numbers, 
      :ent_lading_port_name, :ent_unlading_port_name, :ent_entry_port_name,
      :ent_vessel, :ent_voyage, :ent_importer_tax_id, :ent_cargo_control_number,
      :ent_ship_terms, :ent_direct_shipment_date, :ent_across_sent_date,
      :ent_pars_ack_date, :ent_pars_reject_date, :ent_cadex_accept_date,
      :ent_cadex_sent_date, :ent_exam_ordered_date, :ent_us_exit_port_code, :ent_origin_state_code, 
      :ent_export_state_code, :ent_ca_entry_type, :ent_export_date,
      :ent_export_country_codes, :ent_destination_state, :ent_total_packages,
      :ent_eta_date, :ent_docs_received_date, :ent_first_7501_print, :ent_first_do_issued_date
    ].collect do |mfid|
      m = ModelField.find_by_uid mfid
      raise "BAD #{mfid}" unless m
      m
    end
  end
  def self.criterion_fields_available user
    CoreModule::ENTRY.model_fields(user).values
  end
  def self.can_view? user
    user.view_entries?
  end
  def run run_by, row_limit = nil
    row_cursor = 0
    col_cursor = 0

    #HEADINGS
    write row_cursor, col_cursor, "Container Number"
    col_cursor += 1
    self.search_columns.each do |sc|
      write row_cursor, col_cursor, sc.model_field.label
      col_cursor += 1
    end
    row_cursor += 1
    col_cursor = 0

    entries = Entry.search_secure run_by, Entry.group("entries.id")
    self.search_criterions.each {|sc| entries = sc.apply(entries)}
    
    entries.each do |ent|
      container_numbers = ent.container_numbers
      container_numbers = "N/A" if container_numbers.blank?
      container_numbers.each_line do |cn|
        write row_cursor, col_cursor, cn.strip
        col_cursor += 1
        self.search_columns.each do |sc|
          write row_cursor, col_cursor, sc.model_field.process_export(ent,run_by)
          col_cursor += 1
        end
        col_cursor = 0
        row_cursor += 1
      end
      break if row_limit && row_limit <= row_cursor
    end
    heading_row 0
  end
end
