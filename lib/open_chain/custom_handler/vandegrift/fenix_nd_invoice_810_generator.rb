require 'open_chain/custom_handler/vandegrift/fenix_invoice_810_generator_support'

# Generates a fixed width text file from an Invoice object that can be sent to Fenix through and ecs translation as an 810 invoice
module OpenChain; module CustomHandler; module Vandegrift; class FenixNdInvoice810Generator
  include OpenChain::CustomHandler::Vandegrift::FenixInvoice810GeneratorSupport

  def generate_and_send_810 id_or_invoice, sync_record
    invoice = id_or_invoice.is_a?(Invoice) ? id_or_invoice : Invoice.where(id: id_or_invoice).first

    if invoice
      begin

        Tempfile.open([Attachment.get_sanitized_filename("fenix_invoice_#{invoice_number(invoice)}_"), ".txt"]) do |file|
          write_invoice_810(file, invoice)
          
          ftp_sync_file file, sync_record, ftp_connection_info  
        end
      rescue => e
        e.log_me
        send_invalid_invoice_email(invoice, e.message)
      end
    end
    
    nil
  end

  def write_invoice_810 io, invoice
    write_line io, header_format, invoice
    io << "\r\n"

    line_counter = 0
    rollup_invoice_lines(invoice).each_with_index do |line|
      write_line io, detail_format, invoice, line
      io << "\r\n"
      line_counter += 1
    end

    if line_counter > max_line_count
      raise "Invoice # #{invoice_number(invoice)} generated a Fenix invoice file containing #{line_counter} lines. Invoices over #{max_line_count} lines are not supported and must have detail lines consolidated or the invoice must be split into multiple pieces."
    end

    io.flush
    io.rewind
    nil
  end

  # The invoice_header_map, invoice_detail_map, and invoice_party_map methods should all return a mapping of the fields utilized 
  # to seinvoice data to a lambda, method name, or a constant object.
  # lambdas will be called using instance_exec giving access to local methods and objects returned will be
  # used directly as an output value.
  #
  # Shipper, Consignee and Importer are expected to return company records
  # 
  # You can override this method and use the hash returned as a merge point for any customer specific data points.
  def invoice_header_map
    {
      :record_type => "H",
      :invoice_number => lambda {|i| i.invoice_number.blank? ? "VFI-#{i.id}" : i.invoice_number },
      :invoice_date => lambda {|i| i.invoice_date },
      :country_origin_code => lambda {|i| i.country_origin.try(:iso_code) },
      # There's no actual invoice field for this value, but I don't know when this value would ever not be CA since we're sending to Fenix
      :country_ultimate_destination => "CA",
      :currency => lambda {|i| i.currency },
      :number_of_cartons => lambda {|i| i.invoice_lines.map(&:cartons).compact.sum },
      :gross_weight => lambda {|i| i.gross_weight.presence || BigDecimal("0.00") },
      :total_units => lambda {|i| i.invoice_lines.map(&:quantity).compact.sum },
      :total_value => lambda {|i| i.invoice_total_foreign.presence || BigDecimal("0") },
      :shipper => lambda {|i| i.vendor },
      :consignee => lambda {|i| i.consignee },
      :po_number => lambda {|i| i.invoice_lines.find {|l| !l.po_number.blank? }.try(:po_number) },
      :mode_of_transportation => lambda { |i| mode_of_transportation(i) },
      # We should be sending just "GENERIC" as the importer name in the default case
      # which then will force the ops people to associate the importer account manually as they pull them
      # into the system.  This partially needs to be done based on the way edi in feninx handling is done on a 
      # per file directory basis.  This avoids extra setup when we just want to pull a generic invoice into the system.
      :importer => lambda { |i| Company.new name: "GENERIC" },
      :reference_identifier => lambda {|i| i.customer_reference_number },
      :customer_name => lambda {|i| i.importer.try(:name) },
      :scac => lambda {|i| i.invoice_lines.find {|l| !l.carrier_code.blank? }.try(:carrier_code) },
      :master_bill => lambda {|i| i.invoice_lines.find {|l| !l.master_bill_of_lading.blank? }.try(:master_bill_of_lading).presence || "Not Available" }
    }
  end

  def invoice_detail_map
    {
      :record_type => "D",
      :part_number => lambda {|i, line| line.part_number } ,
      :country_origin_code => lambda {|i, line| line.country_origin.try(:iso_code) },
      # Operations asked us to send a value that would easily let them know the HTS value was
      # invalid for cases where there's no HTS number we could find in the value.  Randy
      # suggested that a value of 0 would always trip any validations and it would 
      # force them to address each invalid line if we did this.
      :hts_code => lambda {|i, line| line.hts_number.presence || "0" },
      :tariff_description => lambda {|i, line| line.part_description },
      :quantity => lambda {|i, line| line.quantity.presence || BigDecimal("0") },
      :unit_price => lambda {|i, line| line.unit_price || BigDecimal("0") },
      :po_number => lambda {|i, line| line.po_number },
      :tariff_treatment => lambda {|i, line| line.spi.presence || "2" }
    }
  end

  def invoice_party_map
    {
      # Fenix expects at least a name for all companies, so in the cases where we don't have one we need to throw
      # in something.
      name: lambda { |c| c.try(:name).presence || "GENERIC" },
      name_2: lambda { |c| c.try(:name_2) },
      address_1: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:line_1) },
      address_2: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:line_2) },
      city: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:city) },
      state: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:state) },
      postal_code: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:postal_code) }
    }
  end

  # If you need to roll up invoice lines, this method should return an array of invoice line and
  # these lines will be those lines that used to build the detail lines output to the file.
  def rollup_invoice_lines invoice
    # By default, no rollup
    invoice.invoice_lines
  end

  # This is just to use the mapping data to extract the invoice number that will be used in the 810, which may 
  # not always come from the invoice's invoice_number field.
  def invoice_number invoice
    mapped_field_value(:invoice_number, invoice_header_map, invoice)
  end

  def mapped_field_value field_name, map, *args
    field = header_format[:fields].find {|f| f[:field] == field_name }
    write_field(field, map[field_name], *args).to_s.strip
  end

  def send_invalid_invoice_email invoice, error_text
    importer_name = invoice.importer.try(:name)
    subject = "Invalid Fenix 810 Invoice for #{importer_name}"
    body = "<p>Failed to generate Fenix 810 invoice due to the following error:<br><br>#{error_text}</p>"

    OpenMailer.send_simple_html(invalid_invoice_error_email_address(), subject, body).deliver_now
  end

  def invalid_invoice_error_email_address
    "edisupport@vandegriftinc.com"
  end

  def max_line_count
    999
  end

  def mode_of_transportation invoice
    mode = invoice.ship_mode.to_s.upcase
    case mode
    when "AIR"
      return "1"
    when "RAIL"
      return "6"
    when "OCEAN"
      return "9"
    else
      # Everything else we'll default to Truck
      return "2"
    end
  end
  
end; end; end; end