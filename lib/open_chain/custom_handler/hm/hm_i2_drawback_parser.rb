require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/csv_excel_parser'

# Fills a table of drawback data.  The one table was meant to contain two varieties of data, which are
# identically structured: export sales and returns.  The shipment type field can be used to differentiate.
module OpenChain; module CustomHandler; module Hm; class HmI2DrawbackParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::CsvExcelParser

  def self.parse_file file, log, opts = {}
    self.new.parse_file file
  end

  def file_reader file
    csv_reader StringIO.new(file), col_sep: ";"
  end

  def parse_file file
    inbound_file.company = Company.importers.where(system_code: "HENNE").first

    lines = foreach(file, skip_blank_lines: true)

    lock_cr = nil
    invoice_number = text_value(lines[0][0])
    inbound_file.add_identifier InboundFileIdentifier::TYPE_INVOICE_NUMBER, invoice_number
    cross_reference_lock_type = determine_cross_reference_lock_type lines[0][8]
    Lock.acquire("Invoice-#{invoice_number}-#{cross_reference_lock_type}") do
      lock_cr = DataCrossReference.where(cross_reference_type: cross_reference_lock_type, key: invoice_number).first_or_create!
    end

    if lock_cr
      # The intention of this check is to prevent two dupe files from being processed near-simultaneously (H&M dupes
      # are a regular problem).  The way we're doing this, we're also effectively eliminating updates at an invoice
      # number level.  Updates are said not to happen.
      Lock.with_lock_retry(lock_cr) do
        # Checking value here ensures that another process didn't already start to lock processing for this invoice
        # number.  A value (current date) will be present only if a file for this invoice number has already been
        # processed.
        if lock_cr.value.nil?
          make_drawback_lines lines

          lock_cr.value = Time.zone.now
          lock_cr.save!
        else
          # Do nothing.  File is quietly rejected.
        end
      end
    end
  end

  private
    def determine_cross_reference_lock_type shipment_type
      case shipment_type.upcase
        when 'ZSTO'
          DataCrossReference::HM_I2_DRAWBACK_EXPORT_INVOICE_NUMBER
        when 'ZRET'
          DataCrossReference::HM_I2_DRAWBACK_RETURNS_INVOICE_NUMBER
        else
          inbound_file.reject_and_raise "Invalid Shipment Type value found: '#{shipment_type}'."
      end
    end

    def make_drawback_lines lines
      lines.each do |line|
        # Skip any lines that are too short.  Some of the older files contain bogus, incomplete final lines.
        next unless line.length >= 20

        shipment_type = translate_shipment_type text_value(line[8])
        invoice_number = text_value(line[0])
        invoice_line_number = text_value(line[1])

        i2_line = HmI2DrawbackLine.where(invoice_number: invoice_number, invoice_line_number: invoice_line_number, shipment_type: shipment_type).first_or_create
        i2_line.shipment_date = line[3].blank? ? nil : Time.zone.parse(line[3])
        i2_line.consignment_number = text_value(line[4])
        i2_line.consignment_line_number = text_value(line[5])
        i2_line.po_number = text_value(line[6])
        i2_line.po_line_number = text_value(line[7])
        # Note that part number is really SKU (which includes the style/part number as its first 7 chars).  We found
        # this out pretty late in the game.
        i2_line.part_number = text_value(line[9])
        i2_line.part_description = text_value(line[10])
        i2_line.origin_country_code = text_value(line[12])
        i2_line.quantity = decimal_value(line[13])
        i2_line.carrier = text_value(line[14])
        i2_line.carrier_tracking_number = text_value(line[15])
        i2_line.customer_order_reference = text_value(line[19])
        i2_line.country_code = text_value(line[26])
        i2_line.return_reference_number = text_value(line[27])
        i2_line.item_value = decimal_value(line[28])
        # Defaulted to true for export sales if the date is from 2017 or later.  For data shipped in
        # Q4 2016, this value is set via the Purolator data feed.  (Considering this project had was
        # still in development in 2019, this is really only relevant for the initial data load.)
        i2_line.export_received = i2_line.shipment_date.present? ? (i2_line.shipment_date >= Date.new(2017, 1, 1)) : false
        i2_line.save!
      end
    end

    # Returns a more human-readable version of the shipment type value.
    def translate_shipment_type orig_shipment_type
      case orig_shipment_type.upcase
        when 'ZSTO'
          shipment_type = 'export'
        when 'ZRET'
          shipment_type = 'returns'
      end
      shipment_type
    end

end;end;end;end