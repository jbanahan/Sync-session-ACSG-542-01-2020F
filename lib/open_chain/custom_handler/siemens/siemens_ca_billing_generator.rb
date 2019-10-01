require 'open_chain/gpg'
require 'open_chain/fixed_position_generator'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module Siemens; class SiemensCaBillingGenerator < OpenChain::FixedPositionGenerator
  include OpenChain::FtpFileSupport

  SiemensEntry ||= Struct.new :entry_port, :entry_number, :broker_reference, :release_date, :cargo_control_number, :ship_mode, :direct_shipment_date, :port_exit, :accounting_date, :importer_tax_id, 
                                :customer_number, :customer_name, :entry_type, :total_duty, :total_sima, :total_excise, :total_gst, :total_amount, :commercial_invoice_lines

  SiemensInvLine ||= Struct.new :vendor_name, :vendor_number, :currency, :exchange_rate, :po_number, :part_number, :quantity, :value, :b3_line_duty_value, :hts, :tariff_provision, :country_origin, :spi, :country_export, :line_number, :duty_rate, 
                                  :sequence_number, :sima_code, :subheader_number, :sima_value, :uom, :gst_rate_code, :gst_amount, :excise_rate_code, :excise_amount,
                                  :value_for_tax, :duty, :entered_value, :special_authority, :description, :value_for_duty_code, :customs_line_number

  def self.run_schedulable opts = {}
    c = opts['public_key'].blank? ? self.new : self.new(opts['public_key'])
    c.generate_and_send c.find_entries
  end

  def initialize public_key_path = "config/siemens.asc"
    raise "Siemens public key must be provided" unless File.exist?(public_key_path)
    @gpg = OpenChain::GPG.new public_key_path

    super({output_timezone: "Eastern Time (US & Canada)"})
  end

  def find_entries
    # We only ever want to send the entry a single time, as such, the standard needs_sync() method is not sufficient for this use-case
    Entry.joins(ActiveRecord::Base.sanitize_sql_array(["LEFT OUTER JOIN sync_records ON sync_records.syncable_type = 'Entry' AND sync_records.syncable_id = entries.id AND sync_records.trading_partner = ?", sync_code])).
      joins(importer: :system_identifiers).
      where(system_identifiers: {system: "Fenix", code: siemens_tax_ids}).
      where("entry_type <> 'F'").
      # Prior to 9/25/2015 this process was done through the old fenix system, so we need to ignore everything done through there.
      where("sync_records.id IS NULL").where("k84_receive_date IS NOT NULL AND k84_receive_date > '2015-09-24'").
      includes(commercial_invoices: [commercial_invoice_lines: [:commercial_invoice_tariffs]]).
      order("entries.k84_receive_date ASC")
  end

  def generate_and_send entries
    counter = billing_file_counter + 1
    sent = false
    filename = "aca#{Time.zone.now.in_time_zone("Eastern Time (US & Canada)").strftime("%Y%m%d")}#{counter}.dat"

    generate_file_data_to_tempfiles(entries, filename) do |outfile, report|
      encrypt_file(outfile) do |encrypted_file|
        Attachment.add_original_filename_method encrypted_file, filename+".pgp"
        completed = false
        error = nil
        begin
          send_time = Time.zone.now
          confirmed = send_time + 1.minute

          # I'm a little uncomfortable putting the entry sync record creations and counter in the same transaction
          # as the ftp (since it's possible the ftp could take a bit), but we really do need to our best to ensure that
          # the ftp and marking entries as sent either all get committed or all get rolled back.  Since  we're sending 
          # to our local connect ftp server on the same network segment the transfer should be very quick so the transaction
          # shouldn't span too much clock time.
          sync_records = []
          Entry.transaction do 
            entries.each do |e|
              sync_records << e.sync_records.build(trading_partner: sync_code, sent_at: send_time, confirmed_at: confirmed)
            end

            counter_item.update_attributes! json_data: {counter: counter}.to_json

            # At this point, since we're in a transaction, the only issue we could run into is if the ftp was successful, but then saving the ftp session
            # data off had an error - which would mean we sent the file but then the sync records and counter would get rolled back.  
            # The chances of that happening are so miniscule that I'm not going to bother handling that condition.
            ftp_sync_file encrypted_file, sync_records

            sync_records.each {|sr| sr.save! }
            
            completed = true
          end
        ensure
          if completed
            now = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now
            OpenMailer.send_simple_html(Group.use_system_group("canada-accounting", name: "VFI Canada Accounting"), "[VFI Track] Siemens Billing Report #{now.strftime("%Y-%m-%d")}", "Attached is the duty data that was sent to Siemens on #{now.strftime("%Y-%m-%d")}.", report).deliver_now
          else
            OpenMailer.send_simple_html(OpenMailer::BUG_EMAIL, "[VFI Track Exception] - Siemens Billing File Error", "Failed to ftp daily Siemens Billing file.  Entries that would have been included in the attached file will be resent during the next run.", outfile).deliver_now
          end
        end
      end
    end
  end

  def generate_file_data_to_tempfiles entries, filename
    # Ensure only a single process can run this at a time.
    Lock.acquire_for_class(self.class, yield_in_transaction: false) do 
      Tempfile.open(["#{File.basename(filename, ".*")}_", "#{File.extname(filename)}"]) do |billing_file|
        # We're encoding the file data directly when writing to the file stream...so make sure 
        # the IO doesn't do any extra encoding translations.
        billing_file.binmode
        # Add the original_filename method, both the ftp and the mailer will utilize this method to name the file when sending
        Attachment.add_original_filename_method billing_file, filename

        Tempfile.open(["#{File.basename(filename, ".*")}_", "#{File.extname(filename)}"]) do |billing_report|
          write_report_headers billing_report
          Attachment.add_original_filename_method billing_report, "siemens-billing-#{Time.zone.now.strftime("%Y-%m-%d")}.csv"
          
          entries.each do |e|
            write_entry_data billing_file, billing_report, generate_entry_data(e)
          end
          billing_file.flush
          billing_file.rewind

          billing_report.flush
          billing_report.rewind

          yield billing_file, billing_report
        end
      end
    end
  end

  def write_entry_data billing_file, billing_report, entry
    # Keep in mind these are the struct classes above, not actual entry/invoice/line classes
    begin
      entry.commercial_invoice_lines.each_with_index do |line, x|
        write_entry_data_line billing_file, entry, line, x == 0
        write_report_data billing_report, entry, line
      end
    rescue => e
      # Rescue the error and then re-raise it after inserting which file # was the culprit for the error
      raise e, "File # #{entry.broker_reference} - #{e.message}", e.backtrace
    end
    nil
  end 

  def write_entry_data_line io, entry, line, first_entry_line = false
    s = StringIO.new
    s << str(line.po_number, 20) # 1-20
    s << str(line.part_number, 20) # 21-40
    s << num(line.quantity, 9, 2) # 41-49
    s << num(line.value, 14, 2) # 50-63
    s << num(line.b3_line_duty_value, 11, 2, numeric_strip_decimals: true, numeric_no_pad_zero: true) # 64-74
    s << str(line.hts, 10) # 75 - 84
    s << num(line.tariff_provision, 4, 0, numeric_pad_char: '0') #85-88
    s << num(entry.entry_port, 4) #89-92
    s << str(entry.entry_number, 14) #93-106
    s << date(entry.release_date) # 107-114
    s << str(line.country_origin, 3) #115-117
    s << num(line.spi, 3) #118-120
    s << str(line.country_export, 3) #121-123
    s << num(line.customs_line_number, 3) # 124-126
    s << str(line.vendor_name, 35) # 127-161
    s << str(line.currency, 3) # 162-164
    s << str(entry.cargo_control_number, 25) #165-189
    s << str(entry.ship_mode, 1) #190
    s << num(line.duty_rate, 9, 5) # 191 -199
    s << num(0, 9, 2) # 200-208
    s << num(line.duty, 11, 2) # 209 - 219
    s << str(entry.broker_reference, 14) # 220 - 233
    s << str(line.vendor_number, 15) # 234-248
    s << num(line.exchange_rate, 9, 6) # 249-257
    s << num(line.value_for_duty_code, 3) # 258-260
    s << num(line.entered_value, 11, 2, numeric_strip_decimals: true) #261-271
    s << str(line.special_authority, 16) # 272 - 287
    s << str(line.description, 59) # 288 - 346
    s << str(line.sequence_number, 16) # 347-362
    s << num(line.sima_code, 3) # 363-365
    s << num(line.subheader_number, 5) # 366 - 370
    s << num(line.sima_value, 11, 2) # 371-281
    s << date(entry.direct_shipment_date) # 382-389
    s << num(entry.port_exit, 4) # 390-393
    s << str(line.uom, 3) #394-396
    s << date(entry.accounting_date) #397-404
    s << str(entry.importer_tax_id, 15) #405-419
    s << str(entry.customer_number, 10) #420-429
    s << str(entry.customer_name, 35) #430 - 464
    s << str(entry.entry_type, 2) #465-466
    s << num(line.gst_rate_code, 4, 2, numeric_strip_decimals: true) # 467-470
    s << num(line.gst_amount, 14, 2) # 471-484
    s << str("", 14) # Previous Transaction # (not using) 485-498
    s << num(0, 3, 0, numeric_pad_char: '0') # 499-501
    s << num(line.excise_rate_code, 7, 0, numeric_pad_char: '0') # 502-508
    s << num(line.excise_amount, 9, 2) # 509-517
    s << num(line.value_for_tax, 14, 2) #518-531
    if first_entry_line
      s << num(entry.total_duty, 14, 2) # 532-545 (Total Duty)
      s << num(entry.total_sima, 11, 2) # 546-556 (Total Sima)
      s << num(entry.total_excise, 11, 2) # 557-567 (Total Excise)
      s << num(entry.total_gst, 11, 2) # 568-578 (Total GST)
      s << num(entry.total_amount, 14, 2) # 579-592 (Total)
    else
      s << num(0, 14, 2) # 532-545 (Total Duty)
      s << num(0, 11, 2) # 546-556 (Total Sima)
      s << num(0, 11, 2) # 557-567 (Total Excise)
      s << num(0, 11, 2) # 568-578 (Total GST)
      s << num(0, 14, 2) # 579-592 (Total)
    end

    # Use windows newlines since the source files we're emulating were done like that.
    s << "\r\n"
    s.flush
    s.rewind

    # Handle the encoding directly here and just replace non-windows charset chars w/ ?.  
    # These are only going to be in descriptions or something like that anyway, so it's not going
    # to be a big deal if they're not showing 100% correct.
    io.write encode(s.read)
    io.flush
    nil
  end

  def write_report_headers io
    headers = []
    headers << "K84 Date"
    headers << "File #"
    headers << "Transaction #"
    headers << "B3 Subheader #"
    headers << "B3 Line #"
    headers << "Line Number"
    headers << "Value for Duty"
    headers << "Duty"
    headers << "Sima"
    headers << "Excise"
    headers << "GST"
    headers << "GST Rate Code"
    headers << "Total"

    io.write headers.to_csv
  end

  def write_report_data io, entry, line
    columns = []
    columns << entry.accounting_date.strftime("%Y-%m-%d")
    columns << entry.broker_reference
    columns << entry.entry_number
    columns << line.subheader_number
    columns << line.customs_line_number
    columns << line.line_number
    columns << line.entered_value
    columns << line.duty
    columns << line.sima_value
    columns << line.excise_amount
    columns << line.gst_amount
    columns << line.gst_rate_code
    columns << (line.duty + line.sima_value + line.excise_amount + line.gst_amount)

    io.write encode(columns.to_csv)
  end

  def encode str
    str.to_s.encode("WINDOWS-1252", invalid: :replace, undef: :replace, replace: "?")
  end

  def generate_entry_data entry
    e = SiemensEntry.new
    e.entry_port = entry.entry_port_code
    e.entry_number = entry.entry_number
    e.broker_reference = entry.broker_reference
    e.release_date = entry.release_date
    e.cargo_control_number = entry.cargo_control_number
    e.ship_mode = entry.transport_mode_code
    e.direct_shipment_date = entry.direct_shipment_date
    e.port_exit = entry.us_exit_port_code
    e.accounting_date = entry.k84_receive_date.presence || entry.cadex_accept_date
    e.importer_tax_id = entry.importer_tax_id
    e.customer_number = entry.customer_number
    e.customer_name = entry.customer_name
    e.entry_type = entry.entry_type
    
    e.commercial_invoice_lines = []

    b3_line_duty_values = Hash.new() {|h, k| h[k] = BigDecimal(0)}

    entry.commercial_invoices.each do |inv|
      inv.commercial_invoice_lines.each do |line|
        line.commercial_invoice_tariffs.each do |tar|
          l = SiemensInvLine.new
          e.commercial_invoice_lines << l

          # Invoice info
          l.vendor_name = inv.vendor_name
          l.vendor_number = inv.mfid
          l.currency = inv.currency
          l.exchange_rate = inv.exchange_rate

          l.line_number = line.line_number
          l.customs_line_number = line.customs_line_number
          l.po_number = line.po_number
          l.part_number = line.part_number
          l.quantity = line.quantity || BigDecimal(0)
          l.b3_line_duty_value = BigDecimal(0)
          l.value = line.value || BigDecimal(0)

          b3_line_duty_values[b3_line_key(l)] += l.value

          l.hts = tar.hts_code.to_s.gsub ".", ""
          l.tariff_provision = tar.tariff_provision
          l.country_origin = country_code(line.country_origin_code, line.state_origin_code)
          l.spi = tar.spi_primary
          l.country_export = country_code(line.country_export_code, line.state_export_code)
          
          
          l.duty_rate = tar.duty_rate.try(:nonzero?) ? (tar.duty_rate * 100) : BigDecimal(0)
          l.duty = tar.duty_amount || BigDecimal(0)
          l.entered_value = tar.entered_value || BigDecimal(0)
          l.special_authority = tar.special_authority
          l.description = tar.tariff_description
          l.sima_code = tar.sima_code.presence || 0
          l.value_for_duty_code = tar.value_for_duty_code.presence || 0
          l.subheader_number = line.subheader_number.presence || BigDecimal(0)
          l.sima_value = tar.sima_amount || BigDecimal(0)
          l.uom = tar.classification_uom_1
          l.gst_rate_code = tar.gst_rate_code.presence || 0
          l.gst_amount = tar.gst_amount || BigDecimal(0)
          l.excise_rate_code = tar.excise_rate_code.presence || 0
          l.excise_amount = tar.excise_amount || BigDecimal(0)
          l.value_for_tax = (l.entered_value + l.duty)
        end
      end
    end


    e.total_duty = e.commercial_invoice_lines.map(&:duty).reduce(:+).presence || 0
    e.total_sima = e.commercial_invoice_lines.map(&:sima_value).reduce(:+).presence || 0
    e.total_excise = e.commercial_invoice_lines.map(&:excise_amount).reduce(:+).presence || 0
    e.total_gst = e.commercial_invoice_lines.map(&:gst_amount).reduce(:+).presence || 0
    e.total_amount = (e.total_duty + e.total_sima + e.total_excise + e.total_gst)

    # Data in the file needs to be ordered by subheader / line numbers
    e.commercial_invoice_lines.sort! do |a, b|
      val = a.subheader_number.to_i <=> b.subheader_number.to_i
      if val == 0
        val = a.customs_line_number.to_i <=> b.customs_line_number.to_i
      end

      if val == 0
        val = a.line_number.to_i <=> b.line_number.to_i
      end

      val
    end

    # Not that we're sorted, go back through and set the sequence number and the per b3 line duty values.
    line_counter = 0
    # Making a copy of the hash to elminate the default hash/key value setting
    b3_line_duty_values = b3_line_duty_values.clone
    e.commercial_invoice_lines.each do |line|
      line.sequence_number = sequence_number(e, (line_counter += 1))

      duty_value = b3_line_duty_values[b3_line_key(line)]
      if duty_value
        line.b3_line_duty_value = duty_value
        # Only the first line of the line number group gets the duty value for the whole set of b3 lines
        b3_line_duty_values.delete b3_line_key(line)
      end
    end

    e
  end

  def ftp_credentials
    connect_vfitrack_net('to_ecs/siemens/billing')
  end

  private
    
    def country_code country_code, state_code
      country_code == "US" ? "U" + state_code : country_code
    end

    def sequence_number entry, line_counter
      if entry.entry_number[-8] == "0"
        transaction_number = "7" + entry.entry_number[-9..-1]
      else
        transaction_number = "70" + entry.entry_number[-8..-1]
      end
      transaction_number + num(line_counter, 6, 0, numeric_pad_char: '0')
    end

    def sum_line_value entry, value_to_sum
      entry.commercial_invoice_lines.inject(BigDecimal(0), :duty)
    end

    def billing_file_counter
      counter_hash = counter_item
      # Since we need to pick up the counter from exactly where the old fenix implementation left off,
      # we should raise an error if the counter is not set up yet to the correct position
      counter = counter_hash.try(:data).try(:[], "counter")
      raise "Siemens Billing file counter must be initialized." unless counter

      counter
    end

    def counter_item
      KeyJsonItem.siemens_billing('counter').first
    end

    def sync_code 
      "Siemens Billing"
    end

    def siemens_tax_ids
      ["868220450RM0001", "836496125RM0001", "868220450RM0007", "120933510RM0001", "867103616RM0001", "845825561RM0001", "843722927RM0001", 
        "868220450RM0022", "102753761RM0001", "897545661RM0001", "868220450RM0009", "892415472RM0001", "867647588RM0001", "871432977RM0001", 
        "868220450RM0004", "894214311RM0001", "868220450RM0003", "868220450RM0005", "815627641RM0001", "807150586RM0002", "807150586RM0001",
        "761672690RM0001", "768899288RM0001", "858557895RM0001"]
    end

    def b3_line_key line
      line.customs_line_number
    end

    def encrypt_file source_file
      Tempfile.open(["siemens_billing", ".dat"]) do |f|
        f.binmode
        @gpg.encrypt_file source_file, f

        yield f
      end

    end

end; end; end; end;
