require 'open_chain/custom_handler/fenix_nd_invoice_generator'
require 'open_chain/custom_handler/fenix_commercial_invoice_spreadsheet_handler'

module OpenChain; module CustomHandler; module Fisher; class FisherCommercialInvoiceSpreadsheetHandler < OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler

  # really only here for testing purposes
  attr_accessor :parameters

  def initialize custom_file
    super(custom_file)
  end

  def process user, parameters = {}
    @parameters = parameters
    super(user)
  end

  def parse_invoice_number_from_row row
    # There is no invoice number in the actual file, which is fine.
    ""
  end

  def prep_header_row row
    # Basically, we're transforming the row from the fisher file, into the layout
    # expected in the standard file format for header data, then the standard
    # handler can take over from there
    header_row = []
    header_row << "101811057RM0001" # Fisher's Tax ID
    header_row << parse_invoice_number_from_row(row)
    header_row << @parameters['invoice_date']
    header_row << row[23]

    header_row
  end

  def prep_line_row row
    line_row = []

    line_row[4] = row[14] # Part number
    line_row[5] = row[23] # Country of Origin
    line_row[7] = row[15] # Description
    line_row[8] = decimal_value(row[12], decimal_places: 5).to_s # Quantity

    total_price = decimal_value(row[20], decimal_places: 5) # Total Value
    quantity = decimal_value(row[12], decimal_places: 5)
    unit_price = "0"
    if quantity.nonzero?
      unit_price = (total_price / quantity).to_s
    end
    line_row[9] = unit_price # Unit Price
    line_row[10] = row[10].to_s.gsub(/\s+001\s*$/, "") # PO Number - strip ' 001' from the end of the PO field
    line_row[11] = "2" # Tariff Treatment

    line_row
  end


end; end; end; end