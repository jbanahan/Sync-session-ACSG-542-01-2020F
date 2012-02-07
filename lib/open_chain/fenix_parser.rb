module OpenChain
  class FenixParser
    SOURCE_CODE = 'Fenix'

    # take the text from a Fenix CSV output file a create entries
    def self.parse file_content
      entry_lines = []
      current_file_number = ""
      CSV.parse(file_content) do |line|
        file_number = line[1]
        if !entry_lines.empty? && file_number!=current_file_number
        debugger
          FenixParser.new.parse_entry entry_lines
          entry_lines = []
        end
        current_file_number = file_number
        entry_lines << line
      end
      FenixParser.new.parse_entry entry_lines unless entry_lines.empty?
    end

    def parse_entry lines
      start_time = Time.now
      #get header info from first line
      process_header lines.first
      lines.each do |x| 
        process_invoice x
        process_invoice_line x
      end
      detail_pos = accumulated_string(:po_number)
      @entry.po_numbers = detail_pos unless detail_pos.blank?
      @entry.master_bills_of_lading = accumulated_string(:bol)
      @entry.container_numbers = accumulated_string(:cont)
      @entry.origin_country_codes = accumulated_string(:org_country)
      @entry.origin_state_codes = accumulated_string(:org_state)
      @entry.export_country_codes = accumulated_string(:exp_country)
      @entry.export_state_codes = accumulated_string(:exp_state)
      @entry.vendor_names = accumulated_string(:vend)
      @entry.save!
      #write time to process without reprocessing hooks
      @entry.connection.execute "UPDATE entries SET time_to_process = #{((Time.now-start_time) * 1000).to_i.to_s} WHERE ID = #{@entry.id}"
    end

    private

    def process_header line
      file_number = line[1]
      @entry = Entry.find_by_broker_reference_and_source_system file_number, SOURCE_CODE
      @entry = Entry.new(:broker_reference=>file_number,:source_system=>SOURCE_CODE) if @entry.nil?
      
      #clear commercial invoices
      @entry.commercial_invoices.destroy_all

      @entry.entry_number = str_val(line[0])
      @entry.import_country = Country.find_by_iso_code('CA')
      @entry.importer_tax_id = str_val(line[3])
      @entry.cargo_control_number = str_val(line[12])
      @entry.ship_terms = str_val(line[17].upcase)
      @entry.direct_shipment_date = parse_date(line[42])
      @entry.transport_mode_code = str_val(line[4])
      @entry.entry_port_code = str_val(line[5])
      @entry.carrier_code = str_val(line[6])
      @entry.voyage = str_val(line[7])
      us_exit = str_val(line[9])
      us_exit = us_exit.rjust(4,'0') unless us_exit.blank?
      @entry.us_exit_port_code = us_exit
      @entry.entry_type = str_val(line[10])
      @entry.duty_due_date = parse_date(line[56])
      @entry.entry_filed_date = @entry.across_sent_date = parse_date_time(line, 57)
      @entry.first_release_date = @entry.pars_ack_date = parse_date_time(line,59)
      @entry.pars_reject_date = parse_date_time(line,61) 
      @entry.release_date = parse_date_time(line,65)
      @entry.cadex_accept_date = parse_date_time(line,67)
      @entry.cadex_sent_date = parse_date_time(line,69)
      @entry.release_type = str_val(line[89])
      @entry.employee_name = str_val(line[88])
      @entry.po_numbers = str_val(line[14])
      file_logged_str = str_val(line[94])
      if file_logged_str.length==10
        @entry.file_logged_date = parse_date_time([file_logged_str,"12:00am"],0)
      end
    end

    def process_invoice line
      @commercial_invoices ||= {}
      @commercial_invoices[line[15]] ||= @entry.commercial_invoices.build
      ci = @commercial_invoices[line[15]]
      ci.invoice_number = str_val(line[16])
      ci.invoice_date = parse_date(line[18])
      ci.vendor_name = str_val(line[11])
      accumulate_string :vend, ci.vendor_name
    end

    def process_invoice_line line
      inv = @commercial_invoices[line[15]]
      inv_ln = inv.commercial_invoice_lines.build
      inv_ln.part_number = str_val(line[23])
      inv_ln.po_number = str_val(line[25])
      inv_ln.units = int_val(line[37])
      inv_ln.unit_of_measure = str_val(line[38])
      accumulate_string :po_number, inv_ln.po_number unless inv_ln.po_number.blank?
      accumulate_string :bol, str_val(line[13])
      accumulate_string :cont, str_val(line[8])
      exp = country_state(line[26])
      org = country_state(line[27])
      inv_ln.country_export_code = exp[0]
      inv_ln.state_export_code = exp[1]
      inv_ln.country_origin_code = org[0]
      inv_ln.state_origin_code = org[1]
      accumulate_string :exp_country, exp[0]
      accumulate_string :exp_state, exp[1]
      accumulate_string :org_country, org[0]
      accumulate_string :org_state, org[1]

      t = inv_ln.commercial_invoice_tariffs.build
      t.spi_primary = str_val(line[28])
      t.hts_code = str_val(line[29])
      t.tariff_provision = str_val(line[30])
      t.classification_qty_1 = int_val(line[31])
      t.classification_uom_1 = str_val(line[32]) 
      t.value_for_duty_code = str_val(line[33])
    end
    
    def int_val val
      val.strip.to_i unless val.blank?
    end
    def str_val val
      return "" if val.match /^[ 0]*$/
      val.strip
    end

    def parse_date d
      s = d.strip
      return nil if s.blank?
      Date.strptime s, '%m/%d/%Y'
    end

    def parse_date_time line, start_pos
      return nil if line[start_pos].blank? || line[start_pos+1].blank?
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse_us_base_format "#{line[start_pos]} #{line[start_pos+1]}"
    end
    def country_state str
      return ["US",str[1,2]] if str.length==3 && str[0]="U"
      return [str,nil]
    end

    def accumulate_string string_code, value
      @accumulated_strings ||= Hash.new
      @accumulated_strings[string_code] ||= Set.new
      @accumulated_strings[string_code] << value unless value.blank?
    end
    def accumulated_string string_code
      return "" unless @accumulated_strings && @accumulated_strings[string_code]
      @accumulated_strings[string_code].to_a.join("\n ")
    end
  end
end
